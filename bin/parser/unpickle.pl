#!/usr/bin/perl
use strict;
use warnings;
use lib '../../lib/';
use WR::Util::Pickle;


my @hex = (@ARGV);
my $str = '';
foreach my $h (@hex) {
    $str .= chr(hex($h));
}
print 'Value...: [', join(' ', @hex), ']', "\n";
print 'Length..: [', length($str), ']', "\n";

my $p = WR::Util::Pickle->new(data => $str);
use Data::Dumper;
print Dumper($p->unpickle);
