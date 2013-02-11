#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use File::Slurp;
use JSON::XS;
use MongoDB;
use boolean;

die 'Usage: mongo-wpa-tanks.pl <file>', "\n" unless($ARGV[0]);
my $file = $ARGV[0];

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.vehicles');

$| = 1;

my $j = JSON::XS->new();

my $d = read_file($ARGV[0]);
my $x = $j->decode($d);

foreach my $wpa_tank (@$x) {
    $coll->update({ label_short => $wpa_tank->{title_short}}, {
        '$set' => { 
            'wpa_tank_id'    => $wpa_tank->{tankid} ,
            'wpa_country_id' => $wpa_tank->{countryid}  
        }
    });
    print $wpa_tank->{title}, ' updated', "\n";
}
