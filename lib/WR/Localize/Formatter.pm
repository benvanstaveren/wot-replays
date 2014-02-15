package WR::Localize::Formatter;
use Moo;

extends 'Data::Localize::Format::Gettext';

sub quant {
    my $self = shift;
    my $meta = shift;
    my $args = shift;

    # quant is a bit of an off-kilter thing, in the sense it doesn't behave like it should ;)
    return ($args->[0] > 1) 
        ? $args->[2]                # plural
        : (defined($args->[3]))     # if we have a 'none' indicator
            ? ($args->[0] == 0)     # and we're 0
                ? $args->[3]        # return that
                : $args->[1]        # or else the singular version
            : $args->[1]            # singular
            ;
}

1;
