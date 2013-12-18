#!/usr/bin/perl
use strict;
use Mango;

my $mango = Mango->new('mongodb://localhost:27017/');
my $db    = $mango->db('wtr-heatmaps');

foreach my $name (@{$db->collection_names}) {
    next unless($name =~ /^(death_|damage_)*locations_(\d+)_(\d+)$/);

    if($name =~ /^death_locations_(\d+)_(\d+)/) {
        print sprintf('mongoexport -d wtr-heatmaps -c %s --jsonArray -o ../../data/packets/heatmaps/d_%d_%d.json', $name, $1, $2), "\n";
    } elsif($name =~ /^locations_(\d+)_(\d+)/) {
        print sprintf('mongoexport -d wtr-heatmaps -c %s --jsonArray -o ../../data/packets/heatmaps/%d_%d.json', $name, $1, $2), "\n";
    } elsif($name =~ /^damage_locations_(\d+)_(\d+)/) {
        print sprintf('mongoexport -d wtr-heatmaps -c %s --jsonArray -o ../../data/packets/heatmaps/dmg_%d_%d.json', $name, $1, $2), "\n";
    }
}
