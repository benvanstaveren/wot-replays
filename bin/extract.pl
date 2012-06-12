#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib);

use WR::Parser::LLFile;

$| = 1;

my $parser = WR::Parser::LLFile->new(file => $ARGV[0]);
print 'blocks: ', $parser->num_blocks, "\n";
print 'extracting data: ';

if($parser->extract_to('./temp.extracted') == 1) {
    print 'OK', "\n";
} else {
    print 'FAIL', "\n";
}
