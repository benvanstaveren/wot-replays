package WR::Role::Process::ExpandResult;
use Moose::Role;
use boolean;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

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

    no warnings;
    my $data = {
        _id => $m_id,
        teams => $ordered_teams,
        team_survivors => $team_survivors,
        processed_at => time(),
        version => substr($self->_parser->wot_version, 0, 5),
        site => {
            meta => {
            },
        },
        game => {
            time => undef,
            type => $res->{gameplayType},
            bonus_type => undef,
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
        complete => ($self->_parser->is_complete) ? true : false,
        vehicles => $res->{vehicles},
        vehicles_hash => $vhash,
        vehicles_hash_name => $vhash_name,
    };

    if($self->_parser->is_complete) {
        $data->{game}->{bonus_type} = $self->match_result->[0]->{bonusType};
        # add some additional fields 
        $data->{game}->{arena_id} = $self->match_result->[0]->{arenaUniqueID};
        $data->{game}->{isWin} = ($self->match_result->[0]->{isWinner} > 0) 
            ? true 
            : ($self->match_result->[0]->{isWinner} < 0) 
                ? false
                : undef;
        $data->{game}->{isDraw} = ($self->match_result->[0]->{isWinner} == 0) ? true : false;
        $data->{game}->{duration}->{seconds} = $self->match_result->[0]->{lifeTime} + 0;
        my $v = $self->match_result->[0]->{lifeTime};
        my $m = int($v/60);
        my $s = $v - ($m * 60);
        $data->{game}->{duration}->{minutes} = sprintf('%s:%s', $m, $s);

        my @ammo_cons = @{$self->match_result->[0]->{ammo}};
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

        $data->{game}->{heroes} = $self->match_result->[0]->{heroVehicleIDs};
        $data->{player}->{statistics} = {
            earned => {
                xp => $self->match_result->[0]->{xp},             # and not tmenXP since that's the amount of XP that went to the crew...
                free_xp => $self->match_result->[0]->{freeXP},
                credits => $self->match_result->[0]->{credits},
                factor => int($self->match_result->[0]->{factors}->{dailyXPFactor10}/10) || 1,
            },
            repair => $self->match_result->[0]->{repair},
            mastery => $self->match_result->[0]->{markOfMastery} + 0,
            capture => {
                gained => $self->match_result->[0]->{capturePoints},
                dropped => $self->match_result->[0]->{droppedCapturePoints},
            },
            consumables => $consumables,
            ammo => $ammo,
            teamkill => {
                rating => $self->match_result->[0]->{tkillRating},
                log    => $self->match_result->[0]->{tkillLog},
            },
            penalties => {
                xp => $self->match_result->[0]->{xpPenalty},
                credits => $self->match_result->[0]->{creditsPenalty},
            },
            shots => {
                fired => $self->match_result->[0]->{shots},
                hits  => $self->match_result->[0]->{hits},
                misses => $self->match_result->[0]->{shots} - $res->{result}->{hits},
                received => $self->match_result->[0]->{shotsReceived},
            },
            damage => {
                done => $self->match_result->[0]->{damageDealt},
                received => {
                    real => $self->match_result->[0]->{damageReceived},
                    potential => $self->match_result->[0]->{potentialDamageReceived},
                }
            },
            survived => ($self->match_result->[0]->{killerID} > 0) ? false : true,
            killed_by => ($self->match_result->[0]->{killerID} > 0) ? $self->match_result->[0]->{killerID} + 0 : undef,
            epic => $self->match_result->[0]->{epicAchievements},
        };

        for(qw/killed spotted damaged/) {
            $data->{player}->{statistics}->{$_} = $self->match_result->[0]->{$_};
        }
        # arena creation time is time in UTC
        $data->{game}->{time} = $self->match_result->[0]->{arenaCreateTime};

        $data->{player}->{killed_by} = undef if($data->{player}->{killed_by} == 0 || $data->{player}->{killed_by} eq '0');
    }

    use warnings;
    return $data;
};

no Moose::Role;
1;
