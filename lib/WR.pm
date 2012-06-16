package WR;
use strict;
use warnings;

BEGIN {

my $libdir = (-e "/home/ben/projects/wot-replays/extlib")
    ? '/home/ben/projects/wot-replays/extlib'
    : '/home/wotreplay/wot-replays/extlib';

my @lib_dirs = ();
my $dir;
opendir($dir, $libdir);
foreach my $e (readdir($dir)) {
    next unless($e !~ /^\./ && -d "$libdir/$e");
    if(-e "$libdir/$e/lib") {
        push(@lib_dirs, "$libdir/$e/lib");
    } else {
        push(@lib_dirs, "$libdir/$e");
    }
}
closedir($dir);
unshift(@INC, @lib_dirs);

}

1;
