package WR;
use strict;
use warnings;

BEGIN {

    my $libdir = (-e "/home/ben/projects/wt-replays/")
        ? '/home/ben/projects/wt-replays/wot-replay-parser'
        : '/home/wotreplay/wt-replays/wot-replay-parser';

    unshift(@INC, sprintf('%s/lib', $libdir));
}

1;
