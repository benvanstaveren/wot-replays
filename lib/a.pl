#!/usr/bin/perl
use strict;
use warnings;
use WR::Res::Achievements;

my $a = WR::Res::Achievements->new;

my @l = ();
foreach my $e (@{$a->achievements}) {
    next unless(defined($e));
    push(@l, $e->{name});
}

print join(' ', sort(@l)), "\n";

