package WR::Process::Offline;
use Mojo::Base 'Mojo::EventEmitter';
use File::Path qw/make_path/;
use Data::Dumper;
use Mango::BSON;
use Try::Tiny qw/try catch/;

use WR::Parser;
use WR::Res::Achievements;
use WR::Provider::ServerFinder;
use WR::Provider::Imager;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;
use WR::Provider::TypeCompResolver;

use Scalar::Util qw/blessed/;

has 'file'          => undef;
has 'mango'         => undef;
has 'bf_key'        => undef;
has 'banner_path'   => undef;
has 'packet_path'   => undef;
has 'banner'        => 1;
has '_error'        => undef;
has '_parser'       => undef;
has 'tcr'           => sub { my $self = shift; return WR::Provider::TypeCompResolver->new(coll => $self->model('wot-replays.data.vehicles')) };
has 'packets'       => sub { [] };
has 'log'           => undef;

sub _log {
    my $self = shift;
    my $level = shift;
    my $msg  = join(' ', @_);

    $self->log->$level($msg);
}

sub warning { shift->_log('warn', @_) }
sub log_error { shift->_log('error', @_) }
sub info { shift->_log('info', @_) }
sub debug { shift->_log('debug', @_) }

sub add_packet {
    my $self    = shift;
    my $packet  = shift;

    push(@{$self->packets}, (blessed($packet)) ? $packet->to_hash : $packet);
}

sub model {
    my $self = shift;
    my $m    = shift;

    my ($db, $coll) = split(/\./, $m, 2);

    return $self->mango->db($db)->collection($coll);
}

sub error {
    my $self = shift;
    my $message = join(' ', @_);

    if(scalar(@_) > 0) {
        $self->_error($message);
        $self->log_error($message);
    } else {
        return $self->_error;
    }
}

sub process {
    my $self = shift;
    my $cb = shift;

    try {
        $self->_real_process(sub {
            my ($p, $replay) = (@_);
            if(defined($replay)) {
                $cb->($self, undef, $replay);
            } else {
                $cb->($self, $self->error, undef);
            }
        });
    } catch {
        my $e = $_;
        $self->log_error($e);
        $self->debug('caught error during processing, error: ', $e, ' calling cb->(self, error, undef)');
        $cb->($self, $e, undef);
    };
}

sub _real_process {
    my $self = shift;
    my $cb = shift;

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );
    
    $self->emit('state.prepare');

    $self->debug('instantiating parser');

    $self->_parser(try {
        return WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_) and $cb->($self, undef);
    });
    $self->debug('parser instantiated');

    # do we need a battle result? well, yeah, I guess we do after all
    $self->error('Replay has no battle result') and $cb->($self, undef) unless($self->_parser->has_battle_result);

    my $battle_result = $self->_parser->get_battle_result;

    $self->debug('setting up temporary result');
    # set up the temporary result 
    my $replay = {
        _id     => Mango::BSON::bson_oid,
        site    => {
            visible     => Mango::BSON::bson_true,
            uploaded_at => Mango::BSON::bson_time,
            downloads   => 0,
            views       => 0,
            likes       => 0,
            last_viewed => Mango::BSON::bson_time(0),
        },
        game    => $self->_game($battle_result),
        stats   => $battle_result->{personal},
        chat    => [],
    };

    # do the game stream, we use a delay as a safeguard to synchronise certain things
    # to make sure everything goes as planned
    if(my $game = $self->_parser->game(Mojo::IOLoop->new)) {
        $self->debug('setting up state.finish delay handler');
        my $delay = Mojo::IOLoop->delay(sub {
            $self->emit('state.finish');

            $self->debug('emitted state.finish');

            $replay->{game}->{recorder}->{consumables} = [ map { $_ + 0 } (keys(%{$game->vcons_initial})) ];
            $replay->{game}->{recorder}->{ammo} = [];

            # ammo is a bit different since the array needs to be hashes of { id => typeid, count => count }
            foreach my $id (keys(%{$game->vshells_initial})) {
                push(@{$replay->{game}->{recorder}->{ammo}}, {
                    id => $id,
                    count => $game->vshells_initial->{$id}->{count},
                });
            }

            $self->emit('state.generatebanner');
            $self->debug('preparing banner');
            $self->generate_banner($replay => sub {
                my $image = shift;
                    
                $replay->{site}->{banner} = $image;
                $replay->{game}->{server} = WR::Provider::ServerFinder->new->get_server_by_id($replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{player}->{accountDBID} + 0);
                $replay->{game}->{recorder}->{index} = $replay->{players}->{$replay->{game}->{recorder}->{name}};

                my $tc = {};
                foreach my $entry (@{$replay->{roster}}) {
                    next unless(length($entry->{player}->{clanAbbrev}) > 0);
                    $tc->{$entry->{player}->{clanAbbrev}}++;
                }

                $replay->{involved} = {
                    players     => [ keys(%{$replay->{players}}) ],
                    clans       => [ keys(%$tc) ],
                    vehicles    => [ map { $_->{vehicle}->{ident} } @{$replay->{roster}} ],
                };

                # we want to store the packets in the database because we'll be streaming them out to the 
                # battle viewer as an event stream, so we can also do a funky progress bar for the loading
                # and other such happy things
                $self->debug('setting up packet store delay');
                my $packet_store_delay = Mojo::IOLoop->delay(sub {
                    # get the WN7 data from Statterbox, since it's on the same machine
                    # we can cheat like hell ;) 
                    
                    $self->debug('setting up wn7 delay');
                    my $wn7_delay = Mojo::IOLoop->delay(sub {
                        $self->debug('emitting state.done, replay process finished');
                        $self->emit('state.done');
                        $cb->($self, $replay);
                    });

                    foreach my $player (keys(%{$replay->{players}})) {
                        my $roster = $replay->{roster}->[ $replay->{players}->{$player} ];
                        my $id     = $roster->{player}->{accountDBID};
                        my $end    = $wn7_delay->begin(0);
                        $self->model('statterbox.summary')->find_one({ _id => $id + 0 } => sub {
                            my ($coll, $err, $summary) = (@_);

                            my $roster = $replay->{roster}->[ $replay->{players}->{$player} ];
                            if(defined($summary)) {
                                $roster->{wn7} = { 
                                    available => Mango::BSON::bson_true,
                                    data => { overall => $summary->{wn7} }
                                };
                                $replay->{wn7} = $roster->{wn7} if($player eq $replay->{game}->{recorder}->{name});
                                $end->();
                            } else {
                                $roster->{wn7} = { 
                                    available => Mango::BSON::bson_false,
                                    data =>{ overall => 0 }
                                };
                                $replay->{wn7} = $roster->{wn7} if($player eq $replay->{game}->{recorder}->{name});
                                $self->model('statterbox.external')->save({
                                    created => Mango::BSON::bson_time,
                                    server  => $replay->{game}->{server},
                                    player  => $player
                                } => sub {
                                    $end->();
                                });
                            }
                        });
                    }
                });
           
                $self->debug('storing packets for replay');

                $self->emit('state.packet.save.start');

                my $packet_end = $packet_store_delay->begin;

                my $base_path = sprintf('%s/%s', $self->packet_path, $self->hashbucket($replay->{_id} . '', 7));
                make_path($base_path) unless(-e $base_path);
                my $packet_file = sprintf('%s/%s.json', $base_path, $replay->{_id} . '');
                if(my $fh = IO::File->new(sprintf('>%s', $packet_file))) {
                    my $json = JSON::XS->new();
                    $fh->print($json->encode($self->packets));
                    $fh->close;
                    $self->debug('wrote packets to file');
                    $self->emit('state.packet.save.done');
                    $packet_end->();
                } else {
                    $self->debug('could not write packets to file');
                    $self->emit('state.packet.save.done');
                    $packet_end->();
                }
            });
        });

        # get some callbacks going
        my $delay_cb = {
            game_version        => $delay->begin,
            game_version_n      => $delay->begin,
            recorder_name       => $delay->begin,
            recorder_id         => $delay->begin,
            setup_battle_level  => $delay->begin,
            setup_roster        => $delay->begin,
            finish              => $delay->begin,
        };

        $self->debug('setting up event handlers');

        $game->on('game.version' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version} = $v;
            $delay_cb->{game_version}->();
        });
        $game->on('game.version_n' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version_numeric} = $v;
            $delay_cb->{game_version_n}->();
        });
        $game->on('recorder.name' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{recorder}->{name} = $v;
            $delay_cb->{recorder_name}->();
        });
        $game->on('recorder.id' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{recorder}->{id} = $v + 0;
            $delay_cb->{recorder_id}->();
        });
        $game->on('setup.battle_level' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{battle_level} = (defined($v)) ? $v + 0 : undef;
            $delay_cb->{setup_battle_level}->();
        });

        # here's some additional bits and pieces that we are interested in
        $game->on('player.position' => sub {
            my ($s, $v) = (@_);
            $self->add_packet($v);
        });
        $game->on('player.orientation.hull' => sub {
            my ($s, $v) = (@_);
            $self->add_packet($v);
        });
        $game->on('player.health' => sub {
            my ($s, $v) = (@_);
            $self->add_packet($v);
        });
        $game->on('setup.roster' => sub {
            my ($s, $roster) = (@_);

            my $name_to_vidx = {};
            my $vid_to_vidx = {};
            my $i = 0;
            my $typecomps = {};
            my $newroster = [];
            my $teams = [];
            my $plat  = {};

            foreach my $entry (@$roster) {
                $name_to_vidx->{$entry->{name}} = $i;
                $vid_to_vidx->{$entry->{vehicleID}} = $i;
                push(@{$teams->[$entry->{team} - 1]}, $i);

                my $rawv = $battle_result->{vehicles}->{$entry->{vehicleID}};
                my $newentry = {
                    health  =>  {
                        total       => ($rawv->{health} + $rawv->{damageReceived}),
                        remaining   => $rawv->{health},
                    },
                    stats => { map { $_ => $rawv->{$_} } (qw/this damageAssistedTrack damageAssistedRadio he_hits pierced kills shots spotted tkills potentialDamageReceived noDamageShotsReceived credits mileage heHitsReceived hits damaged piercedReceived droppedCapturePoints damageReceived killerID damageDealt shotsReceived xp deathReason lifeTime tdamageDealt capturePoints achievements/) },
                    player => $entry,
                    platoon => (defined($plat->{$rawv->{accountDBID}})) ? $plat->{$rawv->{accountDBID}} : undef,
                    vehicle => { id => $entry->{vehicleID} },
                };
                $newentry->{stats}->{isTeamKiller} = ($rawv->{isTeamKiller}) ? Mango::BSON::bson_true : Mango::BSON::bson_false;
                $typecomps->{$entry->{vehicleID}} = $rawv->{typeCompDescr};
                push(@$newroster, $newentry);
                $i++;
            }

            my $teams_sorted = {};
            my $roster_sorted = {};
            my $sort_key = { 
                damageDealt => 'damage',
                xp          => 'xp',
                kills       => 'kills',
            };

            foreach my $key (keys(%$sort_key)) {
                my $sk = $sort_key->{$key};

                $teams_sorted->{$sk} = [ [], [] ];

                foreach my $entry (sort { $b->{stats}->{$key} <=> $a->{stats}->{$key} } (@$newroster)) {
                    push(@{$roster_sorted->{$sk}}, $vid_to_vidx->{$entry->{vehicle}->{id}});
                    push(@{$teams_sorted->{$sk}->[$entry->{player}->{team} - 1]}, $entry->{vehicle}->{id});
                }
            }

            my $t_resolve = {};
            foreach my $key (keys(%$typecomps)) {
                my $tc = $typecomps->{$key};
                if(defined($t_resolve->{$tc . ''})) {
                    push(@{$t_resolve->{$tc . ''}}, $key);
                } else {
                    $t_resolve->{$tc . ''} = [ $key ];
                }
            }

            $self->debug('starting typecomp resolve for roster');
            $self->tcr->fetch([ map { $_ + 0 } (keys(%$t_resolve)) ] => sub {
                my $result = shift;

                foreach my $typecomp (keys(%$result)) {
                    foreach my $vid (@{$t_resolve->{$typecomp}}) {
                        my $idx = $vid_to_vidx->{$vid . ''};
                        my $newvehicle = {};
                        my $vehicle = $result->{$typecomp . ''};
                        foreach my $key (keys(%$vehicle)) {
                            $newvehicle->{$key} = $vehicle->{$key};
                        }
                        $newvehicle->{ident} = delete($newvehicle->{_id});
                        $newvehicle->{id} = $vid + 0;
                        $newvehicle->{icon} = sprintf('%s-%s.png', $vehicle->{country}, $vehicle->{name_lc});
                        $newroster->[$idx]->{vehicle} = $newvehicle;
                    }
                }

                $replay->{roster}        = $newroster;
                $replay->{vehicles}      = $vid_to_vidx;
                $replay->{players}       = $name_to_vidx;
                $replay->{teams}         = $teams;
                $replay->{roster_sorted} = $roster_sorted;
                $replay->{teams_sorted}  = $teams_sorted;

                $replay->{game}->{recorder}->{vehicle} = {
                    id      => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{id},
                    tier    => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{level},
                    ident   => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{ident},
                };
                $delay_cb->{setup_roster}->();
            });
        });
        $game->on('player.chat' => sub {
            my ($game, $chat) = (@_);
            push(@{$replay->{chat}}, $chat);
        });
        $game->on(finish => sub {
            my ($game, $reason) = (@_);
            if($reason->{ok} == 0) {
                $self->error(Dumper($reason)) and $cb->($self, undef);
            } else {
                $self->debug('received finish');
                $delay_cb->{finish}->();
            }
        });

        $self->emit('state.streaming');
        $game->start;
        
        # game->start will exit, so wait for the delay here
        $delay->wait unless(Mojo::IOLoop->is_running);
    } else {
        $self->error('unable to stream replay') and $cb->($self, undef);
    }
}

sub stringify_awards {
    my $self = shift;
    my $res  = shift;
    my $a    = WR::Res::Achievements->new();
    my $t    = [];

    foreach my $item (@{$res->{stats}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $str);
    }
    return $t;
}

sub hashbucket {
    my $self = shift;
    my $str = shift;
    my $l = shift || 6;

    return join('/', (split(//, substr($str, 0, $l))));
}

sub generate_banner {
    my $self = shift;
    my $res  = shift;
    my $cb   = shift;
    my $image;
    my $recorder = $res->{players}->{$res->{game}->{recorder}->{name}};

    $cb->({
        available => Mango::BSON::bson_false,
        error => 'No banner path specified',
    }) and return unless(defined($self->banner_path));

    my $pv = $res->{roster}->[ $recorder ]->{vehicle}->{ident};
    $pv =~ s/:/-/;

    my $xp = $res->{stats}->{xp};
    $xp .= sprintf(' (x%d)', $res->{stats}->{dailyXPFactor10}/10) if($res->{stats}->{dailyXPFactor10} > 10);

    $self->model('wot-replays.data.maps')->find_one({ numerical_id => $res->{game}->{map} } => sub {
        my ($coll, $err, $map) = (@_);
        $cb->({
            available => Mango::BSON::bson_false,
            error => $_,
        }) and return unless(defined($map));
        my $match_result = ($res->{game}->{winner} < 1) 
            ? 'draw'
            : ($res->{game}->{winner} == $res->{roster}->[ $recorder ]->{player}->{team})
                ? 'victory'
                : 'defeat';
                
        my $base_path = sprintf('%s/%s', $self->banner_path, $self->hashbucket($res->{_id} . ''));
        make_path($base_path) unless(-e $base_path);

        my $i = WR::Provider::Imager->new();
        my $imagefile;

        my %imager_args = (
            map     => $map->{_id} . '',
            vehicle => lc($pv),
            result  => $match_result,
            map_name => $map->{label},
            vehicle_name => $res->{roster}->[ $recorder ]->{vehicle}->{label},
            credits => $res->{stats}->{credits},
            xp      => $xp,
            kills   => $res->{stats}->{kills},
            spotted => $res->{stats}->{spotted},
            damaged => $res->{stats}->{damaged},
            player  => $res->{roster}->[ $recorder ]->{player}->{name},
            clan    => $res->{roster}->[ $recorder ]->{player}->{clan},
            destination => sprintf('%s/%s.jpg', $base_path, $res->{_id} . ''),
            awards  => $self->stringify_awards($res),
        );

        try {
            $imagefile = $i->create(%imager_args);
            $image = {
                available => Mango::BSON::bson_true,
                file => $imagefile,
                url_path => sprintf('%s/%s.jpg', $self->hashbucket($res->{_id} . ''), $res->{_id} . ''),
            };
        } catch {
            $image = {
                available => Mango::BSON::bson_false,
                error => $_,
                args  => { %imager_args }
            };
        };
        $cb->($image);
    });
}

sub _game {
    my $self    = shift;
    my $b       = shift;

    # extract:
    # - game type
    # - bonus type 
    # - arena name
    # - arena unique id
    my $game = {
        arena_id        => $b->{arenaUniqueID} . '',       # yes, it's typecasting! In perl! woo!
        duration        => $b->{common}->{duration} + 0,
        started         => Mango::BSON::bson_time($b->{common}->{arenaCreateTime} * 1000),
        winner          => $b->{common}->{winnerTeam},
        bonus_type      => $b->{common}->{bonusType},
        finish_reason   => $b->{common}->{finishReason},
    };

    $game->{recorder}->{team}       = $b->{personal}->{team} + 0;
    $game->{recorder}->{survived}   = ($b->{personal}->{deathReason} == -1) ? Mango::BSON::bson_true : Mango::BSON::bson_false;
    $game->{recorder}->{killer}     = ($b->{personal}->{killerID} > 0) ? $b->{personal}->{killerID} : undef;
    $game->{recorder}->{lifetime}   = $b->{personal}->{lifeTime} + 0;

    my $decoded_arena_type_id = decode_arena_type_id($b->{common}->{arenaTypeID});
    $game->{type} = $decoded_arena_type_id->{gameplay_type};
    $game->{map}  = $decoded_arena_type_id->{map_id};

    return $game;
}

1;
