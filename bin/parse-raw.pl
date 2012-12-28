#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Parser;
use boolean;
use MongoDB;
use Try::Tiny;
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(
    traits => [qw/LL::File Data::Decrypt Data::Reader Data::Attributes/],
    file   => $ARGV[0],
    bf_key => WOT_BF_KEY
    );

print Dumper({ block1 => $parser->decode_block(1), ($parser->is_complete) ? (block2 => $parser->decode_block(2)) : ()});

