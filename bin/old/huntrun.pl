#!/usr/bin/perl
use strict;

my $size = -s 'lakeville.wotreplay.unpacked';

print 'file size: ', $size, "\n";

for(my $i = 0; $i < $size; $i++) {
    printf('[%09d]: checking%s', $i, "\n");
    system(sprintf('./picklehunter.pl %d', $i));
}
