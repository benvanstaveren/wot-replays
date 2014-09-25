#!/usr/bin/perl
use strict;
use warnings;
use lib '../../lib';
use WR::Parser;
use Data::Dumper;

my $parser = WR::Parser->new(file => $ARGV[0]);

print 'Meta: ', "\n", Dumper($parser->meta);
