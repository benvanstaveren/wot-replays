package WR::Role::Process::Banner;
use Moose::Role;
use WR::Imager;
use WR::Res::Achievements;
use Try::Tiny qw/catch try/;

sub stringify_awards {
    my $self = shift;
    my $res  = shift;
    my $a    = WR::Res::Achievements->new();
    my $t    = [];

    foreach my $item (@{$res->{statistics}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $a->index_to_idstr($item->[0]));
    }
    return $t;
}

sub get_base_path {
    my $self = shift;
    my $res  = shift;

    my $filename = $self->file;
    $filename =~ s/(.*)\/.*/$1/gi;
    return $filename;
}

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    try {
        my $pv = $res->{player}->{vehicle}->{full};
        $pv =~ s/:/-/;

        my $xp = $res->{statistics}->{xp};
        if($res->{statistics}->{dailyXPFactor10} > 10) {
            $xp .= sprintf(' (x%d)', $res->{statistics}->{dailyXPFactor10}/10);
        }

        my $i = WR::Imager->new();
        $i->create(
            map     => $res->{map}->{id},
            vehicle => lc($pv),
            result  => 
                ($res->{game}->{isWin})
                    ? 'victory'
                    : ($res->{game}->{isDraw})
                        ? 'draw'
                        : 'defeat',
            map_name => $self->map_name($res->{map}->{id}),
            vehicle_name => $self->vehicle_name($res->{player}->{vehicle}->{full}),
            credits => $res->{statistics}->{credits},
            xp      => $xp,
            kills   => $res->{statistics}->{kills},
            spotted => $res->{statistics}->{spotted},
            damaged => $res->{statistics}->{damaged},
            player  => $res->{player}->{name},
            clan    => $res->{player}->{clan},
            destination => sprintf('%s/%s.png', $self->get_base_path, $res->{_id}->to_string),
            awards  => $self->stringify_awards($res),
        );
    } catch {
    };
    return $res;
};

no Moose::Role;
1;
