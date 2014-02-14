#!/usr/bin/perl
use strict;
use warnings;
use WR::Res::Achievements;

my $a = WR::Res::Achievements->new;

for my $i (qw/64 79/) {
    print 'id ',$i, ' is: ', $a->index_to_idstr($i), "\n";
    for my $c (qw/is_award is_class is_repeatable is_battle/) {
        print $c, ': ', $a->$c($i), "\n";
    }
}
