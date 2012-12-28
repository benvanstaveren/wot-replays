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
    print "$o: ", ref($chunk), ": ", length($chunk), "\n";
    $o++;
}

if($ARGV[1]) {
    my $fh = IO::File->new('>' . $ARGV[1]);
    $fh->binmode(1);
    $fh->print($parser->chunks->[($parser->is_complete) ? 2 : 1]);
    $fh->close();
}

print '--[ Mongo Result ]--------------------------------------------', "\n";
print Dumper($parser->result_for_mongo);
