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

$| = 1;

my $parser = WR::Parser->new(all_chunks => 1);
$parser->parse(read_file($ARGV[0]));
my $o = 0;
print '--[ Chunks ]--------------------------------------------------', "\n";
foreach my $chunk (@{$parser->chunks}) {
    print Dumper($chunk);
}
