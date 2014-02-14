package WR::Util::Pickle::None;
use strict;
use warnings;

sub new { return bless({}, 'WR::Util::Pickle::None') }
sub TO_JSON { return undef }

1;
