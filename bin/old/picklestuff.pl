#!/usr/bin/perl
use strict;
use Data::Dumper;
use Python::Serialize::Pickle::InlinePython;

my $p = Python::Serialize::Pickle::InlinePython->new($ARGV[0]);
while(my $data = $p->load()) {
    warn Dumper($data);
}
