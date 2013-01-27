package WR::Efficiency;
use Moose;

has 'killed'  => (is => 'ro', isa => 'Num', required => 1);
has 'spotted' => (is => 'ro', isa => 'Num', required => 1);
has 'damaged' => (is => 'ro', isa => 'Num', required => 1);
has 'tier'    => (is => 'ro', isa => 'Num', required => 1);

has 'damage_direct'  => (is => 'ro', isa => 'Num', required => 1);
has 'damage_spotted' => (is => 'ro', isa => 'Num', required => 1);

has 'winrate' => (is => 'ro', isa => 'Num', required => 1);
has 'capture_points' => (is => 'ro', isa => 'Num', required => 1);
has 'defense_points' => (is => 'ro', isa => 'Num', required => 1);

use constant E => 2.71828;

sub eff_xvm {
    my $self = shift;

    my $t1 = $self->killed * (350 - $self->tier * 20);
    my $t2 = $self->damage_direct * (0.2 + 1.5/$self->tier);
    my $t3 = 200 * $self->spotted;
    my $t4 = 150 * $self->defense_points;
    my $t5 = 150 * $self->capture_points;

    return $t1 + $t2 + $t3 + $t4 + $t5;
}

sub eff_vba {
    my $self = shift;

    my $t1 = $self->killed * (350 - $self->tier * 20);
    my $t2 = $self->damage_direct * (0.2 + 1.5/$self->tier);
    my $t2_1 = $self->damage_spotted * (0.2 + 1.5/$self->tier);
    my $t3 = 200 * $self->spotted;
    my $t4 = 15 * $self->defense_points;
    my $t5 = 15 * $self->capture_points;

    return $t1 + $t2 + $t2_1 + $t3 + $t4 + $t5;
}

sub min {
    my $self = shift;
    my $v    = shift;
    my $c    = shift;

    return ($v > $c) ? $c : $v;
}


sub eff_wn6 {
    my $self = shift;

    return
        (1240 - 1040 / ($self->min($self->tier, 6)) ** 0.164) * $self->killed
        + $self->damage_direct * 530 / (184 * E ** (0.24 * $self->tier) + 130)
        + $self->spotted * 125
        + $self->min($self->defense_points, 2.2) * 100
        + ((185 / ( 0.17 + E ** (($self->winrate - 35) * -0.134))) - 500) * 0.45
        + (6 - $self->min($self->tier, 6)) * -60
    ;
}

__PACKAGE__->meta->make_immutable;
