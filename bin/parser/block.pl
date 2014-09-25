#!/usr/bin/perl
use strict;
use warnings;
use lib '../../lib';
use WR::Parser qw//;
use Data::Dumper qw/Dumper/;

my $parser = WR::Parser->new(file => $ARGV[0]);

print '--- RAW ---', "\n", $parser->get_block($ARGV[1]), "\n\n";
print '--- DEC ---', "\n", Dumper($parser->decode_block($ARGV[1])), "\n\n";
