#!/usr/bin/perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Parser;
use Data::Dumper;
use Python::Serialize::Pickle::InlinePython;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));
$| = 1;


my $parser = WR::Parser->new(file => $ARGV[0], bf_key => WOT_BF_KEY, traits => [qw/LL::File Data::Decrypt/]);
$parser->unpack_replay(to => sprintf('%s.unpacked', $ARGV[0]));

