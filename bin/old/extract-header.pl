#!/usr/bin/perl
use strict;
use FindBin;

use lib "$FindBin::Bin/../lib/";
use WR;
use WR::Parser;

my $p = WR::Parser->new();
$p->parse(file => $ARGV[0]);

print($p->get_header);
