#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use Scalar::Util qw/blessed/;
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0]);
my $game   = $parser->game_replayer();

$game->start();

print 'Stats........: ', Dumper($game->statistics), "\n";
print 'Personal.....: ', Dumper($game->personal), "\n";
print 'Battleperf...: ', Dumper($game->bperf), "\n";
