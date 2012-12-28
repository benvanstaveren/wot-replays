#!/usr/bin/perl
use strict;
use lib qw(./lib ../lib);
use WR::Res::Achievements;

my $res = {
    achievements => WR::Res::Achievements->new(),
};

print $res->{$ARGV[0]}->i18n($ARGV[1]), "\n";
