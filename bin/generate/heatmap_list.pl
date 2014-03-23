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
    print sprintf(q|<li[%% IF map_ident == '%s' %%] class="active"[%% END %%]><a href="/heatmaps/%s" class="[%% map_ident %%]">[%% h.loc('%s') %%]</a></li>|, $map->{_id}, $map->{slug}, $map->{i18n}), "\n";
}
