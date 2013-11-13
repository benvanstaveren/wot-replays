#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use File::Slurp;
use JSON::XS;
use MongoDB;
use boolean;

die 'Usage: mongo-wpa-maps.pl <file>', "\n" unless($ARGV[0]);
my $file = $ARGV[0];

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.maps');

$| = 1;

my $j = JSON::XS->new();

my $d = read_file($ARGV[0]);
my $x = $j->decode($d);

foreach my $wpa_map (@$x) {
    $coll->update({_id => $wpa_map->{mapidname}}, {
        '$set' => { 'wpa_map_id' => $wpa_map->{mapid}  }
    });
    print $wpa_map->{mapidname}, ' updated', "\n";
}
