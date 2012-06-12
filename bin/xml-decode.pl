#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use WR::XMLReader;
use Data::Dumper;

my $x = WR::XMLReader->new(filename => $ARGV[0]);

my $root = $x->parse();

print Dumper($root);
