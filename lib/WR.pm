package WR;
use strict;
use warnings;

BEGIN {

    my $libdir = (-e "/home/ben/projects/wt-replays/")
        ? '/home/ben/projects/wot-replays/site/extlib/wot-replay-parser'
        : '/home/wotreplay/wot-replays/extlib/wot-replay-parser';

    unshift(@INC, sprintf('%s/lib', $libdir));
}

1;
