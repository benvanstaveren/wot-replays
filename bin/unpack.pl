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

die 'Usage: unpack.pl <infile> <outfile>', "\n" unless($ARGV[1]);

my $parser = WR::Parser->new(
    traits => [qw/LL::File Data::Decrypt Data::Reader Data::Attributes/],
    file   => $ARGV[0],
    bf_key => WOT_BF_KEY,
    cb_gun_shot_count => sub {},
    );

$parser->unpack_replay(to => $ARGV[1]);
