package WR::Process;
use Mojo::Base '-base';
use WR::Parser;
use WR::Wotlabs::Cached;
use File::Path qw/make_path/;
use Data::Dumper;
use Mango::BSON;
use Try::Tiny qw/try catch/;

use WR::Res::Achievements;
use WR::ServerFinder;
use WR::Imager;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;
use WR::TypeCompResolver;

has 'file'          => undef;
has 'mango'         => undef;
has 'bf_key'        => undef;
has 'banner_path'   => undef;
has 'banner'        => 1;
has 'ua'	        => undef; 
has '_error'        => undef;
has '_parser'       => undef;
has 'tcr'           => sub { my $self = shift; return WR::TypeCompResolver->new(coll => $self->model('wot-replays.data.vehicles')) };

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
        die $message, "\n";
    } else {
        return $self->_error;
    }
}

sub process {
    my $self = shift;
    my $cb = shift;

    try {
        $self->_real_process($cb);
    } catch {
        $self->error($_);
        $cb->(0);
    };
}


sub _real_process {
    my $self = shift;
    my $cb = shift;
    my $replay_packets = [];

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );

    $self->_parser(try {
        return WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_) and $cb->(0, $_);
    });

    # do we need a battle result? well, yeah, I guess we do after all
    $self->error('Replay has no battle result') unless($self->_parser->has_battle_result);

    my $battle_result = $self->_parser->get_battle_result;

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
        my $delay = Mojo::IOLoop->delay(sub {
            $replay->{game}->{recorder}->{consumables} = [ map { $_ + 0 } (keys(%{$game->vcons_initial})) ];
            $replay->{game}->{recorder}->{ammo} = [];

            # ammo is a bit different since the array needs to be hashes of { id => typeid, count => count }
            foreach my $id (keys(%{$game->vshells_initial})) {
                push(@{$replay->{game}->{recorder}->{ammo}}, {
                    id => $id,
                    count => $game->vshells_initial->{$id}->{count},
                });
            }

            $self->generate_banner($replay => sub {
                my $image = shift;
                    
                $replay->{site}->{banner} = $image;
                $replay->{game}->{server} = WR::ServerFinder->new->get_server_by_id($replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{player}->{accountDBID} + 0);
                $replay->{game}->{recorder}->{index} = $replay->{players}->{$replay->{game}->{recorder}->{name}};

=pod

Do we really need involved? It's a quick index but maybe better off doing the separate index collection thing?


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

=cut
                warn 'preparing wotlabs fetch', "\n";
                my $wotlabs = WR::Wotlabs::Cached->new(ua => $self->ua, cache => $self->model('wot-replays.cache.wotlabs'));
                warn 'wotlabs instantiated', "\n";
                $wotlabs->fetch($replay->{game}->{server} => [ keys(%{$replay->{players}}) ], sub {
                    my $result = shift;
                    warn 'wotlabs fetch result: ', Dumper($result), "\n";
                    foreach my $player (keys(%$result)) {
                        my $i = $replay->{players}->{$player}; # hope this works
                        $replay->{roster}->[$i]->{wn7} = $result->{$player};
                        $replay->{wn7} = $result->{$player} if($player eq $replay->{game}->{recorder}->{name});
                    }
                    $cb->($replay);
                });
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
            $self->tcr->fetch([ map { $_ + 0 } (keys(%$t_resolve)) ] => sub {
                my $result = shift;

                foreach my $typecomp (keys(%$result)) {
                    foreach my $vid (@{$t_resolve->{$typecomp}}) {
                        my $idx = $vid_to_vidx->{$vid . ''};
                        # swap some shit
                        my $vehicle = $result->{$typecomp . ''};
                        $vehicle->{ident} = delete($vehicle->{_id});
                        $vehicle->{id} = $vid + 0;
                        $vehicle->{icon} = sprintf('%s-%s.png', $vehicle->{country}, $vehicle->{name_lc});
                        $newroster->[$idx]->{vehicle} = $vehicle;
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
                die Dumper($reason), "\n";
            } else {
                $delay_cb->{finish}->();
            }
        });

        $game->start;
        
        # game->start will exit, so wait for the delay here
        $delay->wait unless(Mojo::IOLoop->is_running);
    } else {
        $self->error('unable to stream replay');
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

        my $i = WR::Imager->new();
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
