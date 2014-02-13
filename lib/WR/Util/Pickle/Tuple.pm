package WR::Util::Pickle::Tuple;
use strict;
use warnings;

sub new {
    shift and return bless([@_], 'WR::Util::Pickle::Tuple');
}

1;
