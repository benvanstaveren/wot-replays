package WR::Process;
use Mojo::Base '-base';
use WR::Parser;
use File::Path qw/make_path/;
use Data::Dumper;
use Mango::BSON;
use Try::Tiny qw/try catch/;

use WR::Res::Achievements;
use WR::ServerFinder;
use WR::Imager;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;

has 'file'      => undef;
has 'mango'     => undef;
has 'bf_key'    => undef;
has 'banner_path' => undef;
has '_error'    => undef;
has '_parser'   => undef;
has 'banner'    => 1;

sub model {
    my $self = shift;
    my $m    = shift;

    my ($db, $coll) = split(/\./, $m, 2);

    return $self->mango->db($db)->collection($coll);
}

sub error {
    my $self = shift;
    my $message = join(' ', @_);

    $self->_error($message);
    die '[process]: ', $message, "\n";
}

# some helpers for stream processing
sub packet_is_local {
    my $self    = shift;
    my $players = shift; # our internal list of players 
    my $p       = shift; # the packet object

    # if a packet has no player_id (or an invalid one since we use the assert-bypass mode to get it) 
    # then it's related to the current vehicle, e.g. the one the recorder is controlling or viewing.
    #
    # local packets can be things like camera view direction and zoom level, as well as module repair
    # timers and shell activation 

    if(my $id = $p->to_hash->{player_id}) {
        return 0 if(defined($players->{$id . ''}));
        if(my $id = $p->to_hash(1)->{__props__}->{player_id}) {
            return 0 if(defined($players->{$id . ''}));
        }
    }
    return 1;
}

sub packet_parse_using_format {
    my $self = shift;
    my $po   = shift; # packet object
    my $list = shift;
    my $size = {
        'i' => 4,
        'I' => 4,
        'f' => 4,
        'l' => 4,
        'L' => 4,
        's' => 2,
        'S' => 2,
        'c' => 1,
        'C' => 1,
        'd' => 8,
    };
    my $o = 0;
    my $pd = [];
    my $name;

    foreach my $item (@$list) {
        my $f = substr($item, 0, 1);
        my $s = $size->{$f}; 

        my $data = substr($po->raw_data, $o, $s);
        $o += $s;

        push(@$pd, {
            tmpl => $item,
            unpacked => unpack($item, $data),
            raw => sprintf('%02x ' x $s, map { ord($_) } (split(//, $data))),
        });
    }

    return $pd;
}

sub process {
    my $self = shift;
    my $skip_packets = shift || 0;
    my $replay_packets = [];

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );

    $self->_parser(try {
        return WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_);
    });

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
        %{$self->_players($battle_result)},                 # combines the data from vehicles and players, partially decodes vehicleID for easier lookups later
        stats   => $battle_result->{personal},
        chat    => [],
    };

    if(my $stream = $self->_parser->stream) {
        $stream->on('game.version' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version} = $v;
        });
        $stream->on('game.version.numeric' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{version_numeric} = $v;
        });
        $stream->on('game.recorder' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{recorder}->{name} = $v;
        });
        $stream->on('setup.battle_level' => sub {
            my ($s, $v) = (@_);
            $replay->{game}->{battle_level} = $v + 0;
        });
        $stream->on('setup.fitting' => sub {
            my ($s, $f) = (@_);

            my $id = $f->{id};
            my $idx = $replay->{vehicles}->{$id};

            $replay->{roster}->[$idx]->{vehicle}->{fitting} = $f->{fitting};
        });
        $stream->on('packet' => sub {
            my ($s, $po) = (@_);
            my $p = $po->to_hash;

            if($p->{type} == 0x1f) {
                push(@{$replay->{chat}}, $p->{message});
            } else {
                push(@$replay_packets, $p);
            }
        });
        $stream->start;
    } else {
        $self->error('unable to stream replay');
    }

    $replay->{__packets__} = $replay_packets unless($skip_packets); # this is quite ghetto but..

    my $d = Digest::SHA1->new();
    $d->add($replay->{game}->{recorder}->{name});
    $d->add($replay->{game}->{map});
    $d->add($replay->{game}->{arena_id});
    $d->add($_->{vehicle}->{id}) for(@{$replay->{roster}});

    $replay->{digest} = $d->hexdigest;
    $replay->{site}->{banner} = $self->generate_banner($replay) if(defined($self->banner_path));

    # do a little fixup of things that we needed previous data for
    $replay->{game}->{server} = WR::ServerFinder->new->get_server_by_id($replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{player}->{dbid} + 0);
    $replay->{game}->{recorder}->{index} = $replay->{players}->{$replay->{game}->{recorder}->{name}};

    # here goes
    $replay->{game}->{recorder}->{vehicle} = {
        id      => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{id},
        tier    => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{level},
        ident   => $replay->{roster}->[ $replay->{players}->{$replay->{game}->{recorder}->{name}} ]->{vehicle}->{ident},
    };


    $replay->{involved} = {
        players => [ keys(%{$replay->{players}}) ],
        clans   => [],
        vehicles => [ map { $_->{vehicle}->{ident} } @{$replay->{roster}} ],
    };

    my $tc = {};
    foreach my $entry (@{$replay->{roster}}) {
        next unless(length($entry->{player}->{clan}) > 0);
        $tc->{$entry->{player}->{clan}}++;
    }

    $replay->{involved}->{clans} = [ keys(%$tc) ];
    return $replay;
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
    my $image;
    my $recorder = $res->{players}->{$res->{game}->{recorder}->{name}};

    try {
        my $pv = $res->{roster}->[ $recorder ]->{vehicle}->{ident};
        $pv =~ s/:/-/;

        my $xp = $res->{stats}->{xp};
        $xp .= sprintf(' (x%d)', $res->{stats}->{dailyXPFactor10}/10) if($res->{stats}->{dailyXPFactor10} > 10);

        my $map = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $res->{game}->{map} });
        die 'no map', "\n" unless(defined($map));
        my $match_result = ($res->{game}->{winner} < 1) 
            ? 'draw'
            : ($res->{game}->{winner} == $res->{roster}->[ $recorder ]->{player}->{team})
                ? 'victory'
                : 'defeat';
                
        my $base_path = sprintf('%s/%s', $self->banner_path, $self->hashbucket($res->{_id} . ''));
        make_path($base_path) unless(-e $base_path);

        my $i = WR::Imager->new();
        my $imagefile = $i->create(
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
        $image = {
            available => Mango::BSON::bson_true,
            file => $imagefile,
            url_path => sprintf('%s/%s.jpg', $self->hashbucket($res->{_id} . ''), $res->{_id} . ''),
        };
    } catch {
        $image = {
            available => Mango::BSON::bson_false,
            error => $_,
        };
    };
    return $image;
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

    # add some
    $game->{recorder}->{team} = $b->{personal}->{team} + 0;
    $game->{recorder}->{survived} = ($b->{personal}->{deathReason} == -1) ? Mango::BSON::bson_true : Mango::BSON::bson_false;
    $game->{recorder}->{killer} = ($b->{personal}->{killerID} > 0) ? $b->{personal}->{killerID} : undef;
    $game->{recorder}->{lifetime} = $b->{personal}->{lifeTime} + 0;

    my $decoded_arena_type_id = decode_arena_type_id($b->{common}->{arenaTypeID});

    $game->{type} = $decoded_arena_type_id->{gameplay_type};
    $game->{map} = $decoded_arena_type_id->{map_id};

    return $game;
}

sub get_vehicle_from_typecomp {
    my $self = shift;
    my $typecomp = shift;

    my $t = parse_int_compact_descr($typecomp);
    my $country = nation_id_to_name($t->{country});
    my $wot_id  = $t->{id};

    if(my $v = $self->model('wot-replays.data.vehicles')->find_one({ country => $country, wot_id => $wot_id })) {
        return $v;
    } else {
        return undef;
    }
}

sub _players {
    my $self = shift;
    my $br   = shift;
    my $players = {};
    my $t_p  = {};
    my $plat = {};
    my $teams = [ [], [] ]; # keys on vid
    my $roster = [];
    my $name_to_vidx = {};
    my $vid_to_vidx = {};
    my $i = 0;

    foreach my $dbid (keys(%{$br->{players}})) {
        my $player = $br->{players}->{$dbid};
        $t_p->{$dbid} = {
            dbid => $dbid,
            name => $player->{name},
            clan => $player->{clanAbbrev},
            team => $player->{team}, 
        };
        $plat->{$dbid} = $player->{prebattleID} if($player->{prebattleID} > 0);
    }

    foreach my $vid (keys(%{$br->{vehicles}})) {
        my $rawv = $br->{vehicles}->{$vid};
        my $entry = {
            health  =>  {
                total       => ($rawv->{health} + $rawv->{damageReceived}),
                remaining   => $rawv->{health},
            },
            stats => { map { $_ => $rawv->{$_} } (qw/this damageAssistedTrack damageAssistedRadio he_hits pierced kills shots spotted tkills potentialDamageReceived noDamageShotsReceived credits mileage heHitsReceived hits damaged piercedReceived droppedCapturePoints damageReceived killerID damageDealt shotsReceived xp deathReason lifeTime tdamageDealt capturePoints achievements/) },
            player => $t_p->{$rawv->{accountDBID}},
            platoon => (defined($plat->{$rawv->{accountDBID}})) ? $plat->{$rawv->{accountDBID}} : undef,
            vehicle => {},
        };
        $entry->{stats}->{isTeamKiller} = ($rawv->{isTeamKiller}) ? Mango::BSON::bson_true : Mango::BSON::bson_false;

        # get the vehicle from db
        if(my $v = $self->get_vehicle_from_typecomp($rawv->{typeCompDescr})) {
            $entry->{vehicle} = { id => $vid, ident => $v->{_id} };
            $entry->{vehicle}->{$_} = $v->{$_} for(qw/label label_short level/);
            $entry->{vehicle}->{icon} = sprintf('%s-%s.png', $v->{country}, $v->{name_lc});
        }

        push(@$roster, $entry);
        my $idx = scalar(@$roster) - 1;

        $name_to_vidx->{$entry->{player}->{name}} = $idx;
        $vid_to_vidx->{$vid} = $idx;

        push(@{$teams->[$entry->{player}->{team} - 1]}, $idx);
    }

    # sort the roster and teams by xp earned, damage dealt, and kills made, stores indexes into the roster
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

        foreach my $entry (sort { $b->{stats}->{$key} <=> $a->{stats}->{$key} } (@$roster)) {
            push(@{$roster_sorted->{$sk}}, $vid_to_vidx->{$entry->{vehicle}->{id}});
            push(@{$teams_sorted->{$sk}->[$entry->{player}->{team} - 1]}, $entry->{vehicle}->{id});
        }
    }

    return { 
        roster => $roster, 
        vehicles => $vid_to_vidx, 
        players => $name_to_vidx,
        teams => $teams, 
        roster_sorted => $roster_sorted,
        teams_sorted => $teams_sorted,
        };
}

1;
