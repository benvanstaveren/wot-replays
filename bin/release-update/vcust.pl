#!/usr/bin/perl
use strict;
use FindBin;
use lib ("$FindBin::Bin/lib","$FindBin::Bin/../lib","$FindBin::Bin/../../lib");
use WR;
use WR::XMLReader;
use Mango;
use Mango::BSON;
use JSON::XS;
use XML::Simple;
use File::Slurp qw/read_file/;
use Data::Dumper;

die 'Usage: vcust.pl <path to country customisation.xml> <country>', "\n" unless($ARGV[1]);

my $cfile = $ARGV[0];
my $country = $ARGV[1];

my $data = XMLin($cfile);

my $storage = [];

foreach my $i (keys(%{$data->{inscriptions}->{$country}->{inscriptions}->{inscription}})) {
    my $id = $i;
    $id =~ s/\D+//g;
    $id +=0;

    my $tex = $data->{inscriptions}->{$country}->{inscriptions}->{inscription}->{$i}->{texName};
    $tex =~ s|gui/maps/vehicles/decals|customization|g;
    $tex =~ s/\.dds/\.png/g;

    $tex =~ s/\s+//g;

    push(@$storage, {
        _id     => sprintf('inscription-%s-%d', $country, $id),
        wot_id  => $id,
        icon    => $tex,
        type    => 'inscription',
    });
}

foreach my $i (keys(%{$data->{camouflages}})) {
    my $camo = $data->{camouflages}->{$i};

    my $tex = $camo->{texture};
    $tex =~ s/.*\///g;
    $tex =~ s/\.dds/\.png/g;
    $tex = sprintf('customization/camouflage/%s/%s', $country, $tex);
    $tex =~ s/\s+//g;

    my $id = $camo->{id};
    $id =~ s/\D+//g;
    $id += 0;

    push(@$storage, {
        _id => sprintf('camo-%s-%d', $country, $id),
        wot_id => $id,
        icon => $tex,
        type => 'camo',
    });
}

# have the customisations for emblems and camo for the given country
my $mango = Mango->new('mongodb://localhost:27017/');
my $coll  = $mango->db('wot-replays')->collection('data.customization');

$coll->save($_) for(@$storage);
