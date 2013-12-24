#!/usr/bin/perl
use strict;
use warnings;

my $fmt = shift;
my @hex = (@ARGV);
my $str = '';

foreach my $h (@hex) {
    $str .= chr(hex($h));
}

print 'Value...: [', join(' ', @hex), ']', "\n";
print 'Length..: [', length($str), ']', "\n";
print 'Unpacked: [', join(', ', unpack($fmt, $str)), ']', "\n";
