#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use WR::Provider::Mapgrid;

my $g = WR::Provider::Mapgrid->new(width => 768, height => 768, bounds => [ [ -500, -500 ], [ 500, 500 ] ]);

print 'subcell at ', $ARGV[0], ',', $ARGV[1], ': ', Dumper($g->get_subcell_center_coordinates({ x => $ARGV[0], y => $ARGV[1] })), "\n";
