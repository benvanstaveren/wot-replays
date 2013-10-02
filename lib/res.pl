#!/usr/bin/perl
use strict;
use warnings;
use WR::Res::Achievements;

my $a = WR::Res::Achievements->new();
print $a->index_to_idstr($ARGV[0]);
