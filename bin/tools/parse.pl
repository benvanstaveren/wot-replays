#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR;
use WR::Process::Offline;
use Mango;
use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;
use Try::Tiny;
use Mojo::Log;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mango = Mango->new('mongodb://localhost:27017/');

my $start = [ gettimeofday ];

my $o = WR::Process::Offline->new(
    bf_key          => WOT_BF_KEY,
    banner_path     => '/home/ben/projects/wot-rep;ays/site/data/banners',
    packet_path     => '/home/ben/projects/wot-replays/site/data/packets',
    mango           => $mango,
    file            => $ARGV[0],
    log             => Mojo::Log->new(level => 'debug', path => 'parse.log'),
    );

if(my $d = $o->process) {
    warn Dumper($d);
} else {
    warn 'Error processing: ', $o->error, "\n";
}
