#!/usr/bin/perl
use strict;
use WR::QuickDB;

my $d = WR::QuickDB->new(
    data => [
        { foo => 'bar', id => 10 },
        { foo => 'baz', id => 20 },
    ]
);

print $d->get(id => 10)->{foo}, "\n";
print $d->get(id => 20)->{foo}, "\n";
