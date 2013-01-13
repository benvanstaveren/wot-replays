#!/usr/bin/perl
use strict;
use lib qw(./lib ../lib);
use WR::Res::Achievements;

my $res = WR::Res::Achievements->new();
print $res->is_award($ARGV[0]), "\n";
print $res->is_battle($ARGV[0]), "\n";
print $res->index_to_idstr($ARGV[0]), "\n";
