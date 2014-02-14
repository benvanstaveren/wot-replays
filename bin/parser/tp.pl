#!/usr/bin/perl
use strict;
use lib "../../lib";
use File::Slurp qw/read_file/;
use WR::Util::Pickle;
use Mojo::JSON;
use JSON::XS;

my $l = read_file('test.pickle');
warn 'read: ', length($l), "\n";

my $data = WR::Util::Pickle->new(debug => 1, data => $l)->unpickle;
print Mojo::JSON->new->encode($data);
