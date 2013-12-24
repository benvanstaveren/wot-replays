#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use JSON::XS;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0]);
my $stream = $parser->stream;
my $num    = $ARGV[1] || 1;

my $stats  = {};
my $packets = [];
my $total  = 0;
my $j = JSON::XS->new()->allow_blessed(1)->convert_blessed(1)->pretty(1);

try {
    while(my $packet = $stream->next) {
        $stats->{$packet->type}++;
        $stats->{total}++;
        push(@$packets, $packet);
        $stream->stop if($stats->{total} == $num);
    }
} catch {
    warn 'stream stopped: ', $_, "\n";
};

foreach my $key (sort { $a <=> $b } (keys(%$stats))) {
    warn sprintf('%x', $key), ' = ', $stats->{$key}, "\n";
}

print $j->encode($packets);
