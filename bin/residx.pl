#!/usr/bin/perl
use strict;
use lib qw(./lib ../lib);
use WR::Res::Achievements;

my $res = {
    achievements => WR::Res::Achievements->new(),
};

my $idx = $ARGV[1];
my $w = $ARGV[0];
my $f = ($w eq 'epic') ? 'index_to_epic_idstr' : 'index_to_idstr';

print $w, ' index ', $idx, ' = ', $res->{achievements}->$f($idx), "\n";
