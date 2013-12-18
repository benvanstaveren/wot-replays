#!/usr/bin/perl
use strict;
use File::Slurp qw/read_file/;
use IO::File;
use JSON::XS;
use Mango;

my $j       = JSON::XS->new();

my $mango = Mango->new('mongodb://localhost:27017/');

my $raw     = read_file($ARGV[0]);
my $packets = $j->decode($raw);
