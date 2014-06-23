#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use WR::Parser;
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0], cb_gun_shot_count => sub { return 3 } );
print Dumper($parser->decode_block(1));
print Dumper($parser->decode_block(2));
print Dumper($parser->decode_block(3));

