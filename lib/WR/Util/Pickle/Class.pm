package WR::Util::Pickle::Class;
use strict;
use warnings;

# pretends to be a class
sub new {
    shift and return bless({ args => [ @_ ]}, 'WR::Util::Pickle::Class');
}

1;
