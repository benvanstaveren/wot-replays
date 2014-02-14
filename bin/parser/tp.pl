#!/usr/bin/perl
use strict;
use lib "../../lib";
use File::Slurp qw/read_file/;
use WR::Util::Pickle;

my $l = read_file('test.pickle');
warn 'read: ', length($l), "\n";

my $data = WR::Util::Pickle->new(debug => 1, data => $l)->unpickle;
use Data::Dumper;
print Dumper($data);
