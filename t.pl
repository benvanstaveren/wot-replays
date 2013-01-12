#!/usr/bin/perl

my $v = 11553;

print $v & 15, "\n";
print $v >> 4 & 15, "\n";
print $v >> 8 & 65535, "\n";


my $r = (45 << 8) + (1 + (2 << 4));
print "$r\n";
