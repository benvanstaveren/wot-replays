#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib /home/wotreplay/wot-replays/lib);

use WR::MR;
use Data::Dumper;

my $mr = WR::MR->new();
print Dumper($mr->exec($ARGV[0]));
