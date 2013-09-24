package WR::Process;
use Mojo::Base '-base';
use boolean;
use WR::Parser;
use Data::Dumper;
use WR::Process::Player;
use Mango::BSON;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;
use Try::Tiny qw/try catch/;

has 'file'      => undef;
has 'mango'     => undef;
has 'bf_key'    => undef;
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
        chat    => [],
    };

    my $pignore = { map { $_ => 1 } (qw//) };

    # 0x03 0x05 0x0a - movement, position etc.

    # 0x16, 0x1b 0x22   - seems to be related to camera angles, and zoom level
    # 0x18, 0x19        - always show up in pairs, seems to be some sort of timer since the noticeable values
    #                     will increment in steps about the same as clock data does, perhaps for the in-game
    #                     
    #                     time-remaining counter? 

    # stream packets out 
    if(my $stream = $self->_parser->stream) {
        my $stream_players = {};
        foreach my $vid (keys(%{$replay->{vehicles}})) {
            $stream_players->{$vid} = WR::Process::Player->new(
                health => $replay->{roster}->[$replay->{vehicles}->{$vid}]->{health}->{total},
                name   => $replay->{roster}->[$replay->{vehicles}->{$vid}]->{player}->{name},
            );
        }
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
            $replay->{game}->{recorder} = $v;
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

            return if(defined($p->{player_id}) && !defined($stream_players->{$p->{player_id}}));
            if($p->{type} == 0x1f) {
                push(@{$replay->{chat}}, $p->{message});
            }
        });
        $stream->start;
    } else {
        $self->error('unable to stream replay');
    }
    return $replay;
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
    my $b    = shift;
    my $players = {};
    my $t_p  = {};
    my $plat = {};
    my $teams = [ [], [] ]; # keys on vehicle
    my $roster = [];
    my $name_to_vidx = {};
    my $vid_to_vidx = {};
    my $i = 0;

    foreach my $dbid (keys(%{$b->{players}})) {
        my $player = $b->{players}->{$dbid};
        $t_p->{$dbid} = {
            name => $player->{name},
            clan => $player->{clanAbbrev},
            team => $player->{team}, 
        };
        $plat->{$dbid} = $player->{prebattleID} if($player->{prebattleID} > 0);
    }

    foreach my $vid (keys(%{$b->{vehicles}})) {
        my $rawv = $b->{vehicles}->{$vid};
        my $entry = {
            health  =>  {
                total       => ($rawv->{health} + $rawv->{damageReceived}),
                remaining   => $rawv->{health},
            },
            stats => { map { $_ => $rawv->{$_} } (qw/this damageAssistedTrack damageAssistedRadio he_hits pierced kills shots spotted tkills potentialDamageReceived noDamageShotsReceived credits mileage heHitsReceived hits damaged piercedReceived droppedCapturePoints damageReceived killerID damageDealt shotsReceived xp deathReason lifeTime tdamageDealt capturePoints/) },
            player => $t_p->{$rawv->{accountDBID}},
            platoon => (defined($plat->{$rawv->{accountDBID}})) ? $plat->{$rawv->{accountDBID}} : undef,
            vehicle => {
                
            },
        };
        $entry->{stats}->{isTeamKiller} = ($rawv->{isTeamKiller}) ? Mango::BSON::bson_true : Mango::BSON::bson_false;
        $entry->{stats}->{achievements} = $self->get_achievements($rawv->{achievements});

        # get the vehicle from db
        if(my $v = $self->get_vehicle_from_typecomp($rawv->{typeCompDescr})) {
            $entry->{vehicle} = {};
            $entry->{vehicle}->{$_} = $v->{$_} for(qw/label label_short level/);
            $entry->{vehicle}->{icon} = sprintf('%s-%s.png', $v->{country}, $v->{name_lc});
        }

        push(@$roster, $entry);
        my $idx = scalar(@$roster) - 1;

        $name_to_vidx->{$entry->{player}->{name}} = $idx;
        $vid_to_vidx->{$vid} = $idx;

        push(@{$teams->[$entry->{player}->{team} - 1]}, $idx);
    }

    return { vehicles => $vid_to_vidx, roster => $roster, teams => $teams, players => $name_to_vidx };
}

sub get_achievements {
    my $self = shift;
    my $a = shift;

    return [];
}

sub fuck_booleans {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_booleans($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_booleans($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_booleans($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(ref($obj->{$field}) eq 'JSON::XS::Boolean') {
                $obj->{$field} = ($obj->{$field}) ? true : false;
            }
        }
        return $obj;
    }
}

1;
