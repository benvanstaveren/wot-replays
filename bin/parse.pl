#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Process;
use Mango;
use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;
use Try::Tiny;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mango = Mango->new('mongodb://localhost:27017/');

my $start = [ gettimeofday ];
my $process = WR::Process->new(bf_key => WOT_BF_KEY, file => $ARGV[0], mango => $mango);

my $d;

try {
    $d = $process->process();
} catch {
    die $_, "\n";
    #print 'EXCEPT: ', $_, "\n";
};

my $end = tv_interval($start);

print 'TOOK: ', $end, "\n";

print Dumper($d);
