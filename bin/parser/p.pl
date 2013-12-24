#!/usr/bin/perl
use strict;
use warnings;

my $val = $ARGV[0];
my $fmt = $ARGV[1];

my $res = pack($fmt, $val);

print 'Value: [', $val, ']', "\n";
printf 'Packed: [' . '%02x ' x length($res) . ']', map { ord($_) } (split(//, $res));
print "\n";
