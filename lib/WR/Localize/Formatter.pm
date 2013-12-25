package WR::Localize::Formatter;
use Moo;

extends 'Data::Localize::Format::Gettext';

sub quant {
    my $self = shift;
    my $meta = shift;
    my $args = shift;

    return ($args->[0] > 1) ? $args->[2] : $args->[1];

}

1;
