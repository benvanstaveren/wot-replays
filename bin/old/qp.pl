#!/usr/bin/perl
use strict;
use Search::QueryParser;
use Data::Dumper;

my $qp = new Search::QueryParser;

my $q   = $qp->parse(join(' ', @ARGV)) or die 'No: ', $qp->err, "\n";
print Dumper($q);
