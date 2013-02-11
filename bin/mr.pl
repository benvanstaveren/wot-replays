#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::MR;
use MongoDB;
use Data::Dumper;
$| = 1;

die 'Usage: $0 <mr folder> <output collection> [collection]', "\n" unless($ARGV[1]);
my $coll = $ARGV[2] || 'replays';

my $mongo  = MongoDB::Connection->new({ host => $ENV{MONGO} || 'mongodb://hwn-01.blockstackers.net:27017' });
my $mr     = WR::MR->new(folder => $ARGV[0], db => $mongo->get_database('wot-replays'));

print Dumper($mr->execute($coll => $ARGV[1]));
