package WR::Process::Offline;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::UserAgent;
use File::Path qw/make_path/;
use Data::Dumper;
use Mango::BSON;
use Try::Tiny qw/try catch/;

use WR::Parser;
use WR::Res::Achievements;
use WR::Provider::ServerFinder;
use WR::Provider::Imager;
use WR::Provider::Panelator;
use WR::Provider::WN7;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;

use Scalar::Util qw/blessed/;

use constant PARSER_VERSION => 0; # yeah
use constant PACKET_VERSION => 1; # even more yeah

has 'file'          => undef;
has 'mango'         => undef;
has 'bf_key'        => undef;
has 'banner_path'   => undef;
has 'packet_path'   => undef;
has 'banner'        => 1;
has '_error'        => undef;
has 'has_error'     => 0;
has '_parser'       => undef;
has 'packets'       => sub { [] };
has 'log'           => undef;
has 'ua'            => sub { Mojo::UserAgent->new };

has '_consumables'  => sub { {} }; # consumables are keyed by their typecomp id fragment
has '_components'   => sub { {} }; # components are keyed by type, country, id

has '_rsize'        =>  0;

has '_arena_initialize' => undef;

sub _preload {
    my $self = shift;
    my $cursor = $self->model('wot-replays.data.consumables')->find();
    while(my $c = $cursor->next()) {
        $self->_consumables->{$c->{wot_id}} = $c;
    }

    $cursor = $self->model('wot-replays.data.components')->find();
    while(my $c = $cursor->next()) {
        $self->_components->{$c->{component}}->{$c->{country}}->{$c->{component_id}} = $c;
    }
}

sub get_consumable {
    my $self = shift;
    my $id   = shift;

    return $self->_consumables->{$id};
}

sub get_component {
    my $self = shift;
    my $type = shift;
    my $country = shift;
    my $id = shift;

    return $self->_components->{$type}->{$country}->{$id};
}

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
        $self->has_error(1);
    } else {
        return $self->_error;
    }
}

sub process {
    my $self = shift;
    my $prepared_id = shift;

    $self->_preload;

    my $replay;

    try {
        $replay = $self->_real_process($prepared_id);
    } catch {
        my $e = $_;
        $self->error($e);
        $replay = undef;
    };
    return $replay;
}

sub finalize_roster {
    my $self            = shift;
    my $battle_result   = shift;
    my $replay          = shift;
    my $roster          = shift;

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
        if(my $tc = $typecomps->{$key}) {
            if(defined($t_resolve->{$tc . ''})) {
                push(@{$t_resolve->{$tc . ''}}, $key);
            } else {
                $t_resolve->{$tc . ''} = [ $key ];
            }
        }
    }
    $self->debug('starting typecomp resolve for roster');

    my $cursor = $self->model('wot-replays.data.vehicles')->find({ typecomp => { '$in' => [ map { $_ + 0 } (keys(%$t_resolve)) ] }});
    while(my $tc = $cursor->next()) {
        my $typecomp = $tc->{typecomp};
        foreach my $vid (@{$t_resolve->{$typecomp}}) {
            my $idx = $vid_to_vidx->{$vid . ''};
            my $newvehicle = {};
            my $vehicle = $tc;
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
}

sub _real_process {
    my $self = shift;
    my $prepared_id = shift;

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );
    
    $self->emit('state.prepare.start');
    $self->debug('instantiating parser');

    my $parser;

    try {
        $parser = WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_);
        die('Unable to parse replay: ', $_);
    };

    $self->_parser($parser);

    $self->debug('parser instantiated');
    $self->emit('state.prepare.finish');

    # do we need a battle result? well, yeah, I guess we do after all
    unless($self->_parser->has_battle_result) {
        $self->error('Replay has no battle result');
        return undef;
    }

    my $battle_result = $self->_parser->get_battle_result;

    $self->debug('setting up temporary result');
    # set up the temporary result 
    my $replay = {
        _id     => (defined($prepared_id)) ? $prepared_id : Mango::BSON::bson_oid,
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

    if(my $game = $self->_parser->game()) {
        $game->on('replay.size' => sub {
            my ($s, $v) = (@_);
            $self->_rsize($v);
        });
        $game->on('replay.position' => sub {
            my ($s, $v) = (@_);
            $self->emit('state.streaming.progress' => { count => $v, total => $self->_rsize });
        });
        $game->on('game.version' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version} = $v;
        });
        $game->on('game.version_n' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version_numeric} = $v;
        });
        $game->on('recorder.name' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{recorder}->{name} = $v;
        });
        $game->on('recorder.id' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{recorder}->{id} = $v + 0;
        });
        $game->on('arena.initialize' => sub {
            my ($s, $init) = (@_);
            $replay->{game}->{battle_level} = (defined($init->{battleLevel})) ? $init->{battleLevel} + 0 : undef;
            $replay->{game}->{opponents}    = (defined($init->{opponents})) ? $init->{opponents} : undef;
        });
        # here's some additional bits and pieces that we are interested in
        for my $event ('player.position', 'player.health', 'player.tank.destroyed', 'player.orientation.hull', 'player.chat', 'arena.period', 'player.tank.damaged', 'arena.initialize', 'cell.attention') {
            if($event eq 'player.chat') {
                $game->on($event => sub {
                    my ($game, $chat) = (@_);
                    push(@{$replay->{chat}}, $chat->{text});
                    $self->add_packet($chat);
                });
            } else {
                $game->on($event => sub {
                    my ($s, $v) = (@_);
                    $self->add_packet($v);
                });
            }
        }

        $game->on(finish => sub {
            my ($game, $reason) = (@_);
            if($reason->{ok} == 0) {
                $self->error(Dumper($reason));
                $replay = undef;
            } else {
                $self->emit('state.streaming.finish' => $game->stream->len);

                # finalize the roster
                $self->finalize_roster($battle_result, $replay, $game->roster);

                # we alter the consumables list, the original consumables list contains numbers only, 
                # the new one will have refs
                my $consumables = [];
                foreach my $tc (keys(%{$game->vcons_initial})) {
                    if($tc > 0) {
                        my $a = parse_int_compact_descr($tc);
                        if(my $c = $self->get_consumable($a->{id})) {
                            push(@$consumables, $c);
                        }
                    }
                }

                $replay->{game}->{recorder}->{consumables} = $consumables;
                $replay->{game}->{recorder}->{ammo} = [];

                # ammo is a bit different since the array needs to be hashes of { id => typeid, count => count }
                foreach my $id (keys(%{$game->vshells_initial})) {
                    my $tc = parse_int_compact_descr($id);
                    if(my $a = $self->get_component('shells', nation_id_to_name($tc->{country}), $tc->{id})) {
                        push(@{$replay->{game}->{recorder}->{ammo}}, {
                            ammo  => $a,
                            count => $game->vshells_initial->{$id}->{count},
                        });
                    }
                }

                $self->emit('state.generatebanner.start');
                $self->debug('preparing banner');
                $self->generate_banner($replay => sub {
                    my $image = shift;

                    $self->emit('state.generatebanner.finish');
                        
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

                    $self->debug('storing packets for replay');
                    $self->emit('state.packet.save.start');

                    my $base_path = sprintf('%s/%s', $self->packet_path, $self->hashbucket($replay->{_id} . '', 7));
                    make_path($base_path) unless(-e $base_path);
                    my $packet_file = sprintf('%s/%s.json', $base_path, $replay->{_id} . '');
                    if(my $fh = IO::File->new(sprintf('>%s', $packet_file))) {
                        my $json = JSON::XS->new();
                        $fh->print($json->encode($self->packets));
                        $fh->close;
                        $self->debug('wrote packets to file');
                        $replay->{packets} = sprintf('%s/%s.json', $self->hashbucket($replay->{_id} . '', 7), $replay->{_id} . '');
                        $self->emit('state.packet.save.finish');
                    } else {
                        $self->debug('could not write packets to file');
                        $replay->{packets} = undef;
                        $self->emit('state.packet.save.finish');
                    }

                    $self->debug('fetching wn7 from statterbox');

                    $self->emit('state.wn7.start' => scalar(keys(%{$replay->{players}})));

                    my $count = 0;

                    foreach my $player (keys(%{$replay->{players}})) {
                        my $url = sprintf('http://statterbox.com/api/v1/%s/wn7?server=%s&player=%s', 
                            '5299a074907e1337e0010000',
                            $replay->{game}->{server},
                            lc($player)
                            );

                        $self->debug(sprintf('[%s]: %s', $player, $url));

                        my $roster = $replay->{roster}->[ $replay->{players}->{$player} ];
                        $self->ua->inactivity_timeout(10);

                        if(my $tx = $self->ua->get($url)) {
                            if(my $res = $tx->success) {
                                if($res->json->{ok} == 1) {
                                    if(my $wn7 = $res->json->{data}->{lc($player)}) {
                                        $roster->{wn7} = { 
                                            available => Mango::BSON::bson_true,
                                            data => { overall => $wn7 }
                                        };
                                    } else {
                                        $roster->{wn7} = { 
                                            available => Mango::BSON::bson_false,
                                            data => { overall => 0 }
                                        };
                                    }
                                } else {
                                    $roster->{wn7} = { 
                                        available => Mango::BSON::bson_false,
                                        data => { overall => 0 }
                                    };
                                }
                            } else {
                                $roster->{wn7} = { 
                                    available => Mango::BSON::bson_false,
                                    data => { overall => 0 }
                                };
                            }
                            $replay->{wn7} = $roster->{wn7} if($player eq $replay->{game}->{recorder}->{name});
                        } else {
                            $roster->{wn7} = { 
                                available => Mango::BSON::bson_false,
                                data => { overall => 0 }
                            };
                            $replay->{wn7} = $roster->{wn7} if($player eq $replay->{game}->{recorder}->{name});
                        }
                        $self->emit('state.wn7.progress' => { count => ++$count, total => scalar(keys(%{$replay->{players}})) });
                    }

                    $self->emit('state.wn7.finish');

                    my $wn7p = WR::Provider::WN7->new();
                    my $roster = $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ];
                    my $v = $wn7p->calculate({
                        winrate         => 50,                          # winrate of 50% for per-battle WN7
                        average_tier    => $roster->{vehicle}->{level}, # tier of player vehicle
                        battles         => 1,                           # because it is a single battle
                        destroyed       => $replay->{stats}->{kills},
                        damage_dealt    => $replay->{stats}->{damageDealt},
                        spotted         => $replay->{stats}->{spotted},
                        defense         => $replay->{stats}->{droppedCapturePoints},
                    });

                    $replay->{wn7}->{data}->{battle} = $v;
                });
            }
        });

        $self->emit('state.streaming.start' => $game->stream->len);
        $game->start;

        # after game is done, we should in theory have a replay
        if($self->has_error) {
            return undef;
        } else {
            # yep, replay - in order to fix a few things up so we can use a simplified query,
            # we're now going to construct the panel data 
            my $p = WR::Provider::Panelator->new(db => $self->mango->db('wot-replays')); # hardcoding bad...
            $replay->{panel} = $p->panelate($replay);
            $replay->{parser_version} = $self->PARSER_VERSION;
            $replay->{packet_version} = $self->PACKET_VERSION;
            return $replay;
        }
    } else {
        $self->error('unable to stream replay');
        return undef;
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

    unless(defined($self->banner_path)) {
        $self->warning('[generate_banner]: no banner path specified');
        $cb->({
            available => Mango::BSON::bson_false,
            error => 'No banner path specified',
        });
        return;
    }

    my $pv = $res->{roster}->[ $recorder ]->{vehicle}->{ident};
    $pv =~ s/:/-/;

    my $xp = $res->{stats}->{xp};
    $xp .= sprintf(' (x%d)', $res->{stats}->{dailyXPFactor10}/10) if($res->{stats}->{dailyXPFactor10} > 10);

    if(my $map = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $res->{game}->{map} })) {
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
            clan    => ($res->{roster}->[ $recorder ]->{player}->{clanDBID} > 0) ? $res->{roster}->[ $recorder ]->{player}->{clanAbbrev} : undef,
            destination => sprintf('%s/%s.jpg', $base_path, $res->{_id} . ''),
            awards  => $self->stringify_awards($res),
        );

        $self->debug('[generate_banner]: generating banner using: ', Dumper({%imager_args}));

        try {
            $imagefile = $i->create(%imager_args);
            $image = {
                available => Mango::BSON::bson_true,
                file => $imagefile,
                url_path => sprintf('%s/%s.jpg', $self->hashbucket($res->{_id} . ''), $res->{_id} . ''),
            };
        } catch {
            my $e = $_;
            $image = {
                available => Mango::BSON::bson_false,
                error => $e,
                args  => { %imager_args }
            };
            $self->log_error('Creating image failed: ', $e);
        };
        $cb->($image);
    } else {
        $self->log_error('[generate_banner]: could not find map, disk paths set right?');
        $cb->({
            available => Mango::BSON::bson_false,
            error => $_,
        });
    }
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

    # additional map information we need to get, if we can
    if(my $d = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $game->{map} })) {
        $game->{map_extra} = {
            ident   => $d->{_id},
            slug    => $d->{slug},
            icon    => $d->{icon},
            label   => $d->{label},
            geometry => [ $d->{attributes}->{geometry}->{bottom_left}, $d->{attributes}->{geometry}->{upper_right} ],
        };
    }

    return $game;
}

1;
