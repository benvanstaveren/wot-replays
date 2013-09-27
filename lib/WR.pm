package WR;
use strict;
use warnings;

BEGIN {

    my $libdir = (-e "/home/ben/projects/wt-replays/")
        ? [ '/home/ben/projects/wot-replays/site/extlib/wot-replay-parser', '/home/ben/projects/wot-replays/site/extlib/wot-xml-reader' ]
        : [ '/home/wotreplay/wot-replays/extlib/wot-replay-parser', '/home/wotreplay/wot-replays/extlib/wot-xml-reader' ]
        ;

    foreach my $dir (@$libdir) {
        unshift(@INC, sprintf('%s/lib', $dir));
    }
}

1;
