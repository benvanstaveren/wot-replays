#!/usr/bin/perl
use strict;
use DateTime;

my $dt = DateTime->new(
    year => $ARGV[0],
    month => $ARGV[1],
    day => $ARGV[2],
    hour => $ARGV[3],
    minute => $ARGV[4],
    second => 0,
    time_zone => 'UTC'
);

print 'epoch: ', $dt->epoch, "\n";
