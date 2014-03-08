package WR::Provider::WNx;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;

has 'E' => 2.71828;

sub min {
    my $self = shift;
    my $val  = shift;
    my $cap  = shift;

    return ($val <= $cap) ? $val : $cap;
}

sub max {
    my $self = shift;
    my $val  = shift;
    my $cap  = shift;

    return ($val >= $cap) ? $val : $cap;
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

sub single {
    my $self = shift;
    my $data = shift;
    my $res = 0;
    try {
        $res = $self->_single($data);
    } catch {
        $res = 0;
    };
    return $res;
}

sub calculate {
    my $self = shift;
    my $data = shift;
    my $res  = 0;

    try {
        $res = $self->_calculate($data);
    } catch {
        $res = 0;
    };
    return $res;
}

1;
