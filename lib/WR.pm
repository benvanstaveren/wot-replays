package WR;
use strict;
use warnings;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib"; # should be set already but hey... 
    my @lib_dirs = ();

    # find everything under extlib 
    my $dir;
    opendir($dir, "$FindBin::Bin/../extlib");
    foreach my $e (readdir($dir)) {
        next unless($e !~ /^\./ && -d "$FindBin::Bin/../extlib/$e");
        if(-e "$FindBin::Bin/../extlib/$e/lib") {
            push(@lib_dirs, "$FindBin::Bin/../extlib/$e/lib");
        } else {
            push(@lib_dirs, "$FindBin::Bin/../extlib/$e");
        }
    }
    closedir($dir);
    unshift(@INC, @lib_dirs);
};

1;
