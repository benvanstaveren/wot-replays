#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib);

use WR::Parser;
use boolean;
use Try::Tiny;
use Data::Dumper;
use File::Slurp;
use IO::File;
use JSON::XS;

$| = 1;

my $parser = WR::Parser->new(all_chunks => 1);
$parser->parse(read_file($ARGV[0]));
print '--[ Chunks ]--------------------------------------------------', "\n";
foreach my $chunk (@{$parser->chunks_raw}) {
    print JSON::XS->new()->pretty(1)->encode(JSON::XS->new()->decode($chunk)), "\n";
}
