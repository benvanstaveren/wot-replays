package WR;
use strict;
use warnings;

BEGIN {

    my $libdir = (-e "/home/ben/projects/wot-replays/")
        ? [ '/home/ben/projects/wot-replays/wot-xml-reader', '/home/ben/projects/wot-replays/site/lib' ]
        : [ '/home/wotreplay/wot-xml-reader', '/home/wotreplay/wot-replays/lib' ]
        ;

    foreach my $dir (@$libdir) {
        unshift(@INC, sprintf('%s/lib', $dir));
    }
}

1;
