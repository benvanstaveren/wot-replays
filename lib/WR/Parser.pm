package WR::Parser;
use Moose;
use JSON::XS;
use DateTime;
use boolean;
use Try::Tiny;
use Data::Dumper;

use WR::Parser::LL;

use WR::Res::Achievements;

has 'time_zone' => (is => 'ro', isa => 'Maybe[Str]', required => 1, default => undef);
has 'is_complete' => (is => 'ro', isa => 'Bool', required => 1, default => 0, writer => '_set_is_complete', init_arg => undef);
has 'chunks' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, init_arg => undef, writer => '_set_chunks');
has 'chunks_raw' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, init_arg => undef, writer => '_set_raw_chunks');

sub parse {
    my $self = shift;
    my $raw = join('', @_);
    my $j   = JSON::XS->new();

    my $ll = WR::Parser::LL->new(data => $raw);

    if($ll->complete) {
        my $c1 = $ll->get_block(1);
        my $c2 = $ll->get_block(2);
        $self->_set_raw_chunks([ $c1, $c2 ]);
        $self->_set_chunks([ $j->decode($c1), $j->decode($c2) ]);
    } else {
        my $c1 = $ll->get_block(1);
        $self->_set_raw_chunks([ $c1 ]);
        $self->_set_chunks([ $j->decode($c1) ]);
    }
    $self->_set_is_complete($ll->complete);
}

sub fuck_booleans {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

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

sub result {
    my $self = shift;

    # we basically just sanitize the hashes a little bit
    my $match_info = { %{$self->chunks->[0]} }; # make a copy
    $match_info->{winningTeam} = undef; # unknown

    my $vehicles = [];
    my $realv = ($self->is_complete) ? $self->chunks->[1]->[1] : $match_info->{vehicles};

    foreach my $vid (keys(%$realv)) {
        my $veh = $realv->{$vid};
        my ($v_c, $v_n) = split(/:/, $veh->{vehicleType}, 2);
        $veh->{vehicleType} = {
            name => $v_n,
            country => $v_c,
            full => $veh->{vehicleType},
        };
        my $data = { id => $vid, %$veh };
        if($self->is_complete) {
            $data->{frags} = (defined($self->chunks->[1]->[2]->{$vid}->{frags})) ? $self->chunks->[1]->[2]->{$vid}->{frags} + 0 : 0,
        } else {
            $data->{frags} = undef; 
            $data->{isAlive} = undef; 
        }
        push(@$vehicles, $data);
    }

    $match_info->{vehicles} = $vehicles;
    $match_info->{result} = ($self->is_complete) ? $self->chunks->[1]->[0] : undef;

    return $self->fuck_booleans($match_info);
}

sub result_for_mongo {
    my $self = shift;
    my $res  = $self->result;

    my $dt_str = $res->{dateTime}; # 10.04.2012 20:38:30
    $dt_str =~ s/\W+//g;

    my $m_id = sprintf('%d-%s-%s', $res->{playerID}, $res->{mapName}, $dt_str);

    my $pv = $res->{playerVehicle};
    my ($pv_country, $pv_name) = split(/-/, $pv, 2);

    my $vhash = { map { $_->{id} => $_ } @{$res->{vehicles}} };
    my $vhash_name = { map { $_->{name} => $_ } @{$res->{vehicles}} };

    my $teams = [ 
        [],
        [],
    ];

    my $player_team;
    my $temp_survivors = [ 0, 0 ];

    foreach my $vehicle (@{$res->{vehicles}}) {
        push(@{$teams->[$vehicle->{team} - 1]}, $vehicle->{id});
        $temp_survivors->[$vehicle->{team} -1]++ if($vehicle->{isAlive});
        $player_team = $vehicle->{team} if($vehicle->{name} eq $res->{playerName});
    }

    # figure out which one of these we need to handle
    my $ordered_teams = [];
    my $team_survivors = [];
    if($player_team == 1) {
        $ordered_teams = [ $teams->[0], $teams->[1] ];
        $team_survivors = [ $temp_survivors->[0], $temp_survivors->[1] ];
    } else {
        $ordered_teams = [ $teams->[1], $teams->[0] ];
        $team_survivors = [ $temp_survivors->[1], $temp_survivors->[0] ];
    }

    my $data = {
        _id => $m_id,
        teams => $ordered_teams,
        team_survivors => $team_survivors,
        site => {
            meta => {
            },
        },
        game => {
            time => undef,
            type => $res->{gameplayType},
            isWin => undef,
            arena_id => undef,
            duration => {
                seconds => undef,
                minutes => undef,
            },
            heroes => [],
        },
        map  => {
            id => $res->{mapName},
            name => $res->{mapDisplayName},
        },
        player => {
            id => $res->{playerID} + 0,
            name => $res->{playerName},
            vehicle => {
                country => $pv_country,
                name    => $pv_name,
                full    => sprintf('%s:%s', $pv_country, $pv_name),
            },
            statistics => {
                repair => undef,
                mastery => undef,
                earned => { 
                    xp => undef,
                    free_xp => undef,
                    credits => undef,
                    factor => 1,
                },
                penalties => {
                    xp => undef,
                    credits => undef,
                },
                shots => {
                    fired => undef,
                    hits => undef,
                    misses => undef,
                    received => undef,
                },
                damage => {
                    done => undef,
                    received => {
                        real => undef,
                        potential => undef,
                    },
                },
                survived => undef,
                killed_by => undef,
                killed => [],
                spotted => [],
                damaged => [],
                capture => {
                    gained => undef,
                    dropped => undef,
                },
                consumables => [],
                ammo => [],
                teamkill => {
                    rating => undef,
                    log => [],
                },
            },
        },
        complete => ($self->is_complete) ? true : false,
        vehicles => $res->{vehicles},
        vehicles_hash => $vhash,
        vehicles_hash_name => $vhash_name,
    };

    if($self->is_complete) {
        # add some additional fields 
        $data->{game}->{arena_id} = $res->{result}->{arenaUniqueID};
        $data->{game}->{isWin} = ($res->{result}->{isWinner} > 0) 
            ? true 
            : ($res->{result}->{isWinner} < 0) 
                ? false
                : undef;
        $data->{game}->{isDraw} = ($res->{result}->{isWinner} == 0) ? true : false;
        $data->{game}->{duration}->{seconds} = $res->{result}->{lifeTime} + 0;
        my $v = $res->{result}->{lifeTime};
        my $m = int($v/60);
        my $s = $v - ($m * 60);
        $data->{game}->{duration}->{minutes} = sprintf('%s:%s', $m, $s);

        my @ammo_cons = @{$res->{result}->{ammo}};
        my $ammo = [
            { id => shift(@ammo_cons), remaining => shift(@ammo_cons) },
            { id => shift(@ammo_cons), remaining => shift(@ammo_cons) },
            { id => shift(@ammo_cons), remaining => shift(@ammo_cons) },
        ];
        my $consumables = [
            { id => shift(@ammo_cons), used => (shift(@ammo_cons) || 0 > 0) ? false : true },
            { id => shift(@ammo_cons), used => (shift(@ammo_cons) || 0 > 0) ? false : true },
            { id => shift(@ammo_cons), used => (shift(@ammo_cons) || 0 > 0) ? false : true },
        ];

        my $res_achievements = WR::Res::Achievements->new();

        my $heroes = {};
        my $offset = 0;
        foreach my $vid (@{$res->{result}->{heroVehicleIDs}}) {
            $vid = $vid + 0;
            my $aId = $res->{result}->{achieveIndices}->[$offset];
            push(@{$heroes->{$vid}}, $res_achievements->index_to_idstr($aId));
            $offset++;
        }

        $data->{game}->{heroes} = $heroes;

        $data->{player}->{statistics} = {
            earned => {
                xp => $res->{result}->{xp},             # and not tmenXP since that's the amount of XP that went to the crew...
                free_xp => $res->{result}->{freeXP},
                credits => $res->{result}->{credits},
                factor => int($res->{result}->{factors}->{dailyXPFactor10}/10) || 1,
            },
            repair => $res->{result}->{repair},
            mastery => $res->{result}->{markOfMastery} + 0,
            capture => {
                gained => $res->{result}->{capturePoints},
                dropped => $res->{result}->{droppedCapturePoints},
            },
            consumables => $consumables,
            ammo => $ammo,
            teamkill => {
                rating => $res->{result}->{tkillRating},
                log    => $res->{result}->{tkillLog},
            },
            penalties => {
                xp => $res->{result}->{xpPenalty},
                credits => $res->{result}->{creditsPenalty},
            },
            shots => {
                fired => $res->{result}->{shots},
                hits  => $res->{result}->{hits},
                misses => $res->{result}->{shots} - $res->{result}->{hits},
                received => $res->{result}->{shotsReceived},
            },
            damage => {
                done => $res->{result}->{damageDealt},
                received => {
                    real => $res->{result}->{damageReceived},
                    potential => $res->{result}->{potentialDamageReceived},
                }
            },
            survived => ($res->{result}->{killerID} > 0) ? false : true,
            killed_by => ($res->{result}->{killerID} > 0) ? $res->{result}->{killerID} + 0 : undef,
            epic => [ map { $res_achievements->index_to_epic_idstr($_ + 0) } @{$res->{result}->{epicAchievements}} ],
        };
        for(qw/killed spotted damaged/) {
            $data->{player}->{statistics}->{$_} = $res->{result}->{$_};
        }
        # arena creation time is time in UTC
        $data->{game}->{time} = $res->{result}->{arenaCreateTime};
    } else {
        # game time: the date in the date string is the date on the players' computer,
        # which is going to cause some issues since we don't know where they were when 
        # the replay was uploaded.
        my %dt_args = ();
        if($res->{dateTime} =~ /^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})\:(\d{2})$/) {
            %dt_args = (
                day => $1,
                month => $2,
                year => $3,
                hour => $4,
                minute => $5,
                second => $6,
            );
            $dt_args{'time_zone'} = $self->time_zone if(defined($self->time_zone) && length($self->time_zone) > 0);
        } else {
            die 'could not parse dt str: ', $dt_str, "\n";
        }
        try {
            my $dt = DateTime->new(%dt_args);
            $dt->set_time_zone('UTC');
            $data->{game}->{time} = $dt->epoch;
        } catch {
            die __PACKAGE__, ': error in DT conv: ', $_, ': [', $res->{dateTime}, '] dt_args: ', Dumper({%dt_args}), "\n";
        };
    }
    return $data;
}

__PACKAGE__->meta->make_immutable;
