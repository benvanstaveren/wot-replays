package WR::Role::Process::ExpandResult;
use Moose::Role;
use MongoDB::OID;
use boolean;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    my $m_id = MongoDB::OID->new();

    my $v = $self->_parser->wot_version;
    my $pv = $res->{playerVehicle};
    my ($pv_country, $pv_name) = split(/-/, $pv, 2);

    # alter vehicles, we just want to get the vehicle type out, the rest we'll get from
    # the pickle data
    my $vehicles = $res->{vehicles};
    my $teams    = [ [], [] ];
    my $pid      = $res->{playerID} + 0;
    my $vehicle_hash = {};
    my $all_players  = {};

    if($self->_parser->is_complete) {
        my $pd       = ($self->_parser->is_complete) ? $self->pickledata->{vehicles} : {};
        foreach my $v (sort { $b->{frags} <=> $a->{frags} } (@$vehicles)) {
            my $pv = $pd->{$v->{id}};
            if($self->_parser->is_complete) {
                foreach my $k (keys(%$pv)) {
                    $v->{$k} = $pv->{$k};
                }
            } else {
                $v->{team} = -1;
            }
            push(@{$teams->[ $v->{team} - 1 ]}, $v->{id});
            $vehicle_hash->{$v->{id}} = $v;
        }
        $all_players = $self->pickledata->{players};
    }

    my $data = {
        _id             => $m_id,
        version         => substr($v, 0, 5),
        version_full    => $v,
        site            => { meta => {} },
        game => {
            time        => undef,
            type        => $self->match_info->{gameplayID},
            bonus_type  => undef,
            isWin       => undef,
            arena_id    => undef,
            duration => {
                seconds => undef,
                minutes => undef,
            },
        },
        map  => {
            id          => $res->{mapName},
            name        => $res->{mapDisplayName},
        },
        player => {
            id          => $pid,
            name        => $res->{playerName},
            vehicle => {
                country => $pv_country,
                name    => $pv_name,
                full    => sprintf('%s:%s', $pv_country, $pv_name),
            },
            killed_by   => ($self->_parser->is_complete)
                ? $self->pickledata->{personal}->{killerID} + 0
                : undef,
            survived    => ($self->_parser->is_complete) 
                ? ($self->pickledata->{personal}->{killerID} + 0 == 0) 
                    ? 1 
                    : 0
                : -1,
            team        => ($self->_parser->is_complete) ? $self->pickledata->{personal}->{team} + 0 : -1
        },
        players  => $all_players,
        complete => ($self->_parser->is_complete) ? true : false,
        vehicles => $vehicle_hash,
        teams    => $teams,
        statistics => {},
    };

    if($self->_parser->is_complete) {
        $data->{statistics} = $self->pickledata->{personal};

        $data->{game}->{arena_id} = $self->pickledata->{arenaUniqueID} + 0;

        $data->{game}->{bonus_type} = $self->pickledata->{common}->{bonusType};
        $data->{game}->{isWin} = ($self->match_result->[0]->{isWinner} > 0) 
            ? true 
            : ($self->match_result->[0]->{isWinner} < 0) 
                ? false
                : undef;
        $data->{game}->{isDraw} = ($self->match_result->[0]->{isWinner} == 0) ? true : false;

        $data->{game}->{duration}->{seconds} = $self->pickledata->{common}->{duration} + 0;
        my $v = int($self->pickledata->{common}->{duration} + 0);
        my $m = int($v/60);
        my $s = $v - ($m * 60);
        $data->{game}->{duration}->{minutes} = sprintf('%s:%s', $m, $s);

        $data->{game}->{lifetime}->{seconds} = $self->pickledata->{personal}->{lifeTime};
        $v = int($self->pickledata->{personal}->{lifeTime} + 0);
        $m = int($v/60);
        $s = $v - ($m * 60);
        $data->{game}->{lifetime}->{minutes} = sprintf('%s:%s', $m, $s);

        $data->{game}->{time}        = $self->pickledata->{common}->{arenaCreateTime};
        $data->{player}->{killed_by} = undef if($data->{player}->{killed_by} + 0 == 0);

        # add a few things to the player
        if($self->_parser->wot_ammo_consumables_available) {
            $data->{player}->{loadout} = {
                ammo            => $self->_parser->wot_ammo,
                consumables     => $self->_parser->wot_consumables,
            };
        }
    }
    use warnings;
    return $data;
};

no Moose::Role;
1;
