package WR::Provider::WN7;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;

use constant E => 2.71828;

sub min {
    my $self = shift;
    my $val  = shift;
    my $cap  = shift;

    return ($val <= $cap) ? $val : $cap;
}

sub safe_div {
    my $self = shift;
    my $a    = shift;
    my $b    = shift;
    my $r    = 0;

    try {
        $r = $a / $b;
    } catch {
        $r = 0;
    };
    return $r;
}

sub pow {
    my $self = shift;
    my $a    = shift;
    my $b    = shift;

    return $a ** $b;
}

sub calculate {
    my $self = shift;
    my $data = shift;
    my $wn7;

    try {
        $wn7 = $self->_calculate($data);
    } catch {
        $wn7 = 0;
    };
    return $wn7;
}

sub _calculate {
    my $self = shift;
    my $data = shift;

    my $average_tier = sprintf('%.2f', $data->{average_tier});
    my $games_played = sprintf('%.2f', $data->{battles});
    my $frags        = sprintf('%.2f', $data->{destroyed});
    my $damage       = sprintf('%.2f', $data->{damage_dealt});
    my $spotted      = sprintf('%.2f', $data->{spotted});
    my $defense      = sprintf('%.2f', $data->{defense});
    my $winrate      = sprintf('%.2f', $data->{winrate});

    my $frag_factor     = (1240 - 1040/($self->min($average_tier, 6)) ** 0.164) * $frags;
    my $damage_factor   = $damage * 530 / (184 * E ** (0.24 * $average_tier) + 130);
    my $spot_factor     = $spotted * 125 * ($self->min($average_tier, 3)/3);
    my $defense_factor  = $self->min($defense, 2.2) * 100;
    my $winrate_factor  = ((185/(0.17 + E ** (($winrate - 35) * -0.134))) - 500) * 0.45;
    my $low_penalty     = ((5 - $self->min($average_tier, 5)) * 125) / (1 + E ** ( ( $average_tier - ($games_played / 220) ** (3 / $average_tier)) * 1.5));

    my $wn7 = int($frag_factor + $damage_factor + $spot_factor + $defense_factor + $winrate_factor - $low_penalty);

    return $wn7;
}

1;
