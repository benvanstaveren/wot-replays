#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
use WR::Parser;
use Mojo::IOLoop;
use JSON::XS;
use IO::File;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0], cb_gun_shot_count => sub { return 3 } );

print 'num blocks....: ', $parser->num_blocks, "\n";
print 'pickle at.....: ', $parser->pickle_block, "\n";

my $stats = {};
my $pickle_stats = {};
my $jp = [];
my $lp;

print 'have battle result: ', ($parser->has_battle_result) ? 'yes' : 'no', "\n";
print 'battle result: ', Dumper($parser->get_battle_result), "\n";
