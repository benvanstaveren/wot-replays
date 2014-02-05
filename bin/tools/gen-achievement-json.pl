#!/usr/bin/perl
use strict;
use warnings;
use lib "../../lib";
use WR::Res::Achievements;
use Data::Localize::Gettext;

my $a = WR::Res::Achievements->new();
my $loc = Data::Localize::Gettext->new(path => '../../lang/wg/common/achievements.po');

use Data::Dumper;
my $r = [];

for my $id (keys(%{$a->achievements})) {
    next unless(defined($a->{achievements}->{$id}));
    my $t = $loc->localize_for(lang => 'achievements', id => $a->achievements->{$id});
    push(@$r, {
        id    => $id + 0,
        ident => $a->achievements->{$id},
        title => (defined($t)) ? $t : $a->achievements->{$id},
    });
}

use JSON::XS;
my $j = JSON::XS->new()->pretty(1);
print $j->encode($r);
