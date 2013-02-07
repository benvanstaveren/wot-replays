package WR::Role::Process::ExpandResult;
use Moose::Role;
use MongoDB::OID;
use boolean;
use WR::Util::TypeComp qw/parse_int_compact_descr/;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;

sub get_vehicle_tier {
    my $self = shift;
    my $id   = shift;

    if(my $v = $self->db->get_collection('data.vehicles')->find_one({ _id => $id })) {
        return $v->{level} + 0;
    } else {
        return 0;
    }
}

sub get_vehicle_player {
    my $self = shift;
    my $pv   = shift;

    my $id   = $pv->{accountDBID};
    return $self->pickledata->{players}->{$id};
}

sub find_player_data {
    my $self = shift;
    my $res  = shift;

    my $dbid = $self->pickledata->{personal}->{accountDBID};
    my $data = {
        player => $self->pickledata->{players}->{$dbid},
        player_dbid => $dbid,
    };

    foreach my $k (keys(%{$self->pickledata->{vehicles}})) {
        my $v = $self->pickledata->{vehicles}->{$k};
        if($v->{accountDBID} == $dbid) {
            $data->{vehicle} = $v;
            $data->{vehicle_id} = $k;
            last;
        }
    }
    return $data;
}

sub get_game_data {
    my $self = shift;
    my $playerdata = $self->find_player_data;
    my $data = {
        arena_id    => $self->pickledata->{arenaUniqueID} . '', # stringify it since it's inordinately large
        bonus_type  => $self->pickledata->{common}->{bonusType} + 0,
        isWin       => ($self->pickledata->{common}->{winnerTeam} > 0 && $self->pickledata->{common}->{winnerTeam} == $playerdata->{vehicle}->{team}) 
            ? true 
            : false,
        isDraw      => ($self->pickledata->{common}->{winnerTeam} == 0) 
            ? true 
            : false,
        finishReason=> $self->pickledata->{common}->{finishReason},
        duration    => {
            seconds => $self->pickledata->{common}->{duration} + 0,
        },
        lifetime    => {
            seconds => $self->pickledata->{personal}->{lifeTime} + 0,
        },
        time        => $self->pickledata->{common}->{arenaCreateTime} + 0,
        type        => decode_arena_type_id($self->pickledata->{common}->{arenaTypeID})->{gameplay_type},
    };

    my $v = int($self->pickledata->{common}->{duration} + 0);
    my $m = int($v/60);
    my $s = $v - ($m * 60);
    $data->{duration}->{minutes} = sprintf('%s:%s', $m, $s);

    $v = int($self->pickledata->{personal}->{lifeTime} + 0);
    $m = int($v/60);
    $s = $v - ($m * 60);
    $data->{lifetime}->{minutes} = sprintf('%s:%s', $m, $s);
    return $data;
}

sub get_player_data {
    my $self = shift;
    my $pd   = $self->find_player_data;

    my $veh = $self->pickledata->{vehicles}->{$pd->{vehicle_id}};
    my $tc = parse_int_compact_descr($veh->{typeCompDescr});

    my $v_c = nation_id_to_name($tc->{country});
    # get the vehicle name out of the database
    my $vehicle = $self->model('wot-replays.data.vehicles')->find_one({
        country => $v_c,
        wot_id  => $tc->{id},
    });

    my $player_vehicle = {
        name    => $vehicle->{name},
        country => $v_c,
        full    => $vehicle->{_id},
        tier    => $vehicle->{level},
        label   => $vehicle->{label},
        label_short => $vehicle->{label_short},
        type    => $vehicle->{type},
        icon    => $self->vicon($vehicle->{_id}),
    };

    # player survived if:
    # no killer
    # vehicle health > 0
    #
    # doesn't work for drowning, apparently... no crew activity flags available.

    my $data = {
        id          => $pd->{vehicle_id},
        account_id  => $pd->{player_dbid} + 0,
        name        => $pd->{player}->{name},
        clan        => (length($pd->{player}->{clanAbbrev}) > 0) ? $pd->{player}->{clanAbbrev} : undef,
        vehicle     => $player_vehicle,
        killed_by   => ($self->pickledata->{personal}->{killerID} > 0) ? $self->pickledata->{personal}->{killerID} + 0 : undef,
        team        => $self->pickledata->{personal}->{team} + 0,
    };

    $data->{survived} = (defined($data->{killed_by}) || $pd->{vehicle}->{health} <= 0) ? false : true;
    return $data;
}

sub get_map_data {
    my $self = shift;
    my $map_id = decode_arena_type_id($self->pickledata->{common}->{arenaTypeID})->{map_id};
    my $map = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $map_id });
    die '[process]: can not seem to resolve map with arenaTypeID ', $self->pickledata->{common}->{arenaTypeID}, "\n" unless(defined($map));
    return {
        id   => $map->{_id},
        name => $map->{label},
    };
}

sub vicon {
    my $self = shift;
    my ($vc, $vn) = split(/\:/, shift, 2);

    return lc(sprintf('%s-%s.png', $vc, $vn));
}

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    my $m_id = MongoDB::OID->new();
    my $v = $self->_parser->wot_version;
    my $vehicles = {};

    foreach my $vid (keys(%{$self->pickledata->{vehicles}})) {
        my $veh = $self->pickledata->{vehicles}->{$vid};
        my $tc = parse_int_compact_descr($veh->{typeCompDescr});

        my $v_c = nation_id_to_name($tc->{country});
        # get the vehicle name out of the database
        my $vehicle = $self->model('wot-replays.data.vehicles')->find_one({
            country => $v_c,
            wot_id  => $tc->{id},
        });
        $veh->{vehicleType} = {
            name    => $vehicle->{name},
            country => $v_c,
            full    => $vehicle->{_id},
            label   => $vehicle->{label},
            tier    => $vehicle->{level},
            type    => $vehicle->{type},
            label_short => $vehicle->{label_short},
            icon    => $self->vicon($vehicle->{_id}),
        };
        my $pd = $self->get_vehicle_player($veh);
        my $data = { 
            id => $vid, 
            %$veh, 
            name    => $pd->{name},
            frags   => $veh->{kills} + 0,
            isAlive => ($veh->{health} > 0) ? 1 : 0,
            clanAbbrev => (length($pd->{clanAbbrev}) > 0) ? $pd->{clanAbbrev} : undef,
        };
        $vehicles->{$vid} = $data;
    }

    my $playerdata = $self->find_player_data;
    my $teams    = [ [], [] ];

    foreach my $k (keys(%$vehicles)) {
        push(@{$teams->[ $vehicles->{$k}->{team} - 1 ]}, $k);
    }

    my $player_clan = $playerdata->{player}->{clanAbbrev};
            
    my $data = {
        _id             => $m_id,
        version         => substr($v, 0, 5),
        version_full    => $v,
        site            => { 
            meta => {
                views       => 0,
                likes       => 0,
                downloads   => 0,
            } 
        },
        game => $self->get_game_data,
        map  => $self->get_map_data,
        player => $self->get_player_data,
        players  => $self->pickledata->{players},
        complete => true, # we're always complete
        vehicles => $vehicles,
        teams    => $teams,
        statistics => $self->pickledata->{personal},
    };

    $data->{statistics}->{xp_base} = 0;
    $data->{statistics}->{credits_base} = 0;
    $data->{involved} = {
        players => [],
        clans   => [],
    };

    my $tclan = {};

    foreach my $vehicle (values(%{$data->{vehicles}})) {
        next unless(defined($vehicle->{name}));
        if($vehicle->{name} eq $data->{player}->{name}) {
            $data->{statistics}->{xp_base} = $vehicle->{xp} + 0;
            $data->{statistics}->{credits_base} = $vehicle->{credits} + 0;
        } else {
            push(@{$data->{involved}->{players}}, $vehicle->{name});
            $tclan->{$vehicle->{clanAbbrev}}++ if(defined($vehicle->{clanAbbrev}) && length($vehicle->{clanAbbrev}) > 0);
        }
    }

    # fix clan involvement
    $data->{involved}->{clans} = [ keys(%$tclan) ];

    # add a few things to the player
    if($self->_parser->wot_ammo_consumables_available) {
        $data->{player}->{loadout} = {
            ammo            => $self->_parser->wot_ammo,
            consumables     => $self->_parser->wot_consumables,
        };
    } else {
        $data->{player}->{loadout} = {
            ammo        => [ undef, undef, undef ],
            consumables => [ undef, undef, undef ],
        };
    }
    return $data;
};

no Moose::Role;
1;
