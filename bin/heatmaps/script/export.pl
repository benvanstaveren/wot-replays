#!/usr/bin/perl
use strict;
use Mango;

my $mango = Mango->new('mongodb://localhost:27017/');
my $db    = $mango->db('wtr-heatmaps');

foreach my $name (@{$db->collection_names}) {
    if($name =~ /^locations_(\d+)_(\d+)$/) {
        print sprintf('mongoexport -d wtr-heatmaps -c %s --jsonArray -o ../../data/packets/heatmaps/%d_%d.json', $name, $1, $2), "\n";
    } elsif($name =~ /^(.*)_locations_(\d+)_(\d+)$/) {
        my $type = $1;
        my $gameid  = $2;
        my $bonusid = $3;
        my $prefix = {
            'death' => 'd',
            'damage_r' => 'dmg',
            'damage_d' => 'dd',
        };
        print sprintf('mongoexport -d wtr-heatmaps -c %s --jsonArray -o ../../data/packets/heatmaps/%s_%d_%d.json', $name, $prefix->{$type}, $gameid, $bonusid), "\n";
    }
}
