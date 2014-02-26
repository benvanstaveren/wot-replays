#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use JSON::XS;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => shift(@ARGV));
my $stream = $parser->stream;

my $packets = [];
my $j = JSON::XS->new()->allow_blessed(1)->convert_blessed(1)->pretty(1);

my $mcount = scalar(@ARGV);

try {
    while(my $packet = $stream->next) {
        # each entry in argv is a set of hex chars we want to grep for 
        my $mc = 0;
        foreach my $e (@ARGV) {
            $mc++ if($packet->payload_hex =~ /$e/);
        }
        push(@$packets, $packet->to_hash) if($mc == $mcount);
    }
} catch {
    print 'stream stopped: ', $_, "\n";
};


my $pc = {};

foreach my $p (@$packets) {
    my $s = sprintf('%02x-%02x %02d-%02d', $p->{type}, $p->{subtype}, $p->{type}, $p->{subtype});
    $pc->{$s}++;
}

print $j->encode($packets);

foreach my $t (sort { $pc->{$a} <=> $pc->{$b} } keys(%$pc)) {
    print $t, ' = ', $pc->{$t}, "\n";
}
    
