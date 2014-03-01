package WR::Provider::Panelator;
use Mojo::Base '-base';
use Mango::BSON;

has 'db' => undef;

sub model {
    my $self = shift;
    my $c    = shift;

    return $self->db->collection($c);
}

sub generate_map_extra {
    my $self   = shift;
    my $replay = shift;
    my $panel  = shift;
    my $cb     = shift;

    $self->model('data.maps')->find_one({ numerical_id => $replay->{game}->{map} } => sub {
        my ($c, $e, $d) = (@_);
        if(defined($d)) {
            $panel->{map} = {
                ident   => $d->{_id},
                slug    => $d->{slug},
                icon    => $d->{icon},
                label   => $d->{label},
                geometry => [ $d->{attributes}->{geometry}->{bottom_left}, $d->{attributes}->{geometry}->{upper_right} ],
            };
        }
        return $cb->($panel);
    });
}

sub panelate {
    my $self   = shift;
    my $replay = shift;
    my $cb     = shift;

    my $panel = {
        file    => $replay->{file},
        spotted => $replay->{stats}->{spotted},
        spotted_damage => $replay->{stats}->{damageAssistedRadio} + $replay->{stats}->{damageAssistedTrack},
        killed => $replay->{stats}->{kills},
        damaged => $replay->{stats}->{damaged},
        damage_dealt => $replay->{stats}->{damageDealt},
        survived => $replay->{game}->{recorder}->{survived},
        server => $replay->{game}->{server},
        version => $replay->{version} || $replay->{game}->{version}, # fallback in case of re-paneling
        credits => $replay->{stats}->{credits},
        xp => $replay->{stats}->{xp},
        multiplier => $replay->{stats}->{dailyXPFactor10} / 10,
        winner => $replay->{game}->{winner},
        team => $replay->{game}->{recorder}->{team},
        id => $replay->{_id},
        premium => ($replay->{stats}->{isPremium} > 0) ? Mango::BSON::bson_true : Mango::BSON::bson_false,
        name => $replay->{game}->{recorder}->{name},
        bonus_type => $replay->{game}->{bonus_type},
        game_type  => $replay->{game}->{type},
    };

    if(defined($replay->{wn7})) {
        $panel->{wn7} = {
            overall => $replay->{wn7}->{data}->{overall},
            battle  => $replay->{wn7}->{data}->{battle},
        };
    } elsif(defined($replay->{wn8})) {
        $panel->{wn8} = {
            overall => $replay->{wn8}->{data}->{overall},
            battle  => $replay->{wn8}->{data}->{battle},
        };
    }

    my $roster = $replay->{roster}->[ $replay->{game}->{recorder}->{index} ];

    $panel->{vehicle} = {
        label       => $roster->{vehicle}->{label},
        label_short => $roster->{vehicle}->{label_short},
        icon        => $roster->{vehicle}->{icon},
        ident       => $roster->{vehicle}->{ident},
        i18n        => $roster->{vehicle}->{i18n},
    };

    if(defined($replay->{game}->{map_extra})) {
        $panel->{map} = $replay->{game}->{map_extra};
        return $cb->($panel);
    } else {
        return $self->generate_map_extra($replay => $panel => $cb);
    }
}

1;
