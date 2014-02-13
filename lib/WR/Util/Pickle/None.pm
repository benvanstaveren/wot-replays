package WR::Util::Pickle::None;
use strict;
use warnings;

sub new {
    return bless({}, 'WR::Util::Pickle::None');
}

1;
