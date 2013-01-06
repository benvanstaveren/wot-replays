#!/usr/bin/perl
use strict;
use lib qw(./lib ../lib);
use WR::Res::Achievements;
use Data::Dumper;

my $ac = WR::Res::Achievements->new();

foreach my $id (sort( { $a <=> $b } (keys(%{$ac->achievements})))) {
    printf "%03d: %s\n", $id, $ac->achievements->{$id};
}
