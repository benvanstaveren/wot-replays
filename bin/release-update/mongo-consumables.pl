#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use JSON::XS;
use Data::Localize;
use Data::Localize::Gettext;
use File::Slurp qw/read_file/;
use Mango;
use Data::Dumper;

die 'Usage: mongo-consumables.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/artefacts.po', $version));

my $mango  = Mango->new('mongodb://localhost:27017/');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('data.consumables');

$| = 1;

my $j = JSON::XS->new();

my $f = sprintf('../../etc/res/raw/%s/consumables.json', $version);
print 'processing: ', $f, "\n";
my $d = read_file($f);
my $x = $j->decode($d);

foreach my $id (keys(%$x)) {
    next if($id eq 'text');
    my $data = $x->{$id};
    my $icon = $data->{icon};
    $icon =~ /artefact\/(.*?).png\s.*/;
    $icon = sprintf('%sIcon.png', $1);
    my $us = $data->{userString};

    $us =~ s/^#artefacts://g;
    
    my $m = {
        _id     =>  sprintf('%s_%s', $id, $data->{id} + 0),
        wot_id  =>  $data->{id} + 0,
        icon    =>  $icon,
        name    =>  $id,
        label   =>  $text->localize_for(lang => 'artefacts', id => $us),
        i18n    =>  $data->{userString},
    };

    $coll->save($m);
}
