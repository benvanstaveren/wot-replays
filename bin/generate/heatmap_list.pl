#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Mango;

my $mango  = Mango->new($ENV{'MONGO'} || 'mongodb://localhost:27017');
my $db     = $mango->db('wot-replays');

foreach my $map (@{$db->collection('data.maps')->find()->sort({ label => 1 })->all()}) {
    next if($map->{slug} eq 'trainingarea');
    print sprintf(q|<li><a href="/heatmaps/%s">[%% h.loc('%s') %%]</a></li>|, $map->{slug}, $map->{i18n}), "\n";
}
