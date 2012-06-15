#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Process;
use boolean;
use MongoDB;
use Try::Tiny;
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');

my $process = WR::Process->new(file => $ARGV[0], db => $db, bf_key => WOT_BF_KEY);
print Dumper($process->process());
