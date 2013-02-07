#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use MongoDB;
use boolean;

die 'Usage: mongo-maps.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/arenas.po', $version));

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.maps');

my $x = XMLin(sprintf('../etc/res/raw/%s/arena.xml', $version));
use Data::Dumper;
foreach my $map (keys(%{$x->{map}})) {
    my ($dummy, $id) = split(/_/, $map, 2);
    my $name = $text->localize_for(lang => 'arenas', id => sprintf('%s/name', $map));

    my $icon = lc($name);
    $icon =~ s/'//g;
    $icon =~ s/\W+/_/g;

    my $data = {
        _id             => $map,
        name_id         => $id,
        numerical_id    => $x->{map}->{$map}->{id} + 0,
        label           => $name,
        slug            => lc($name),
        icon            => sprintf('%s.jpg', $icon),
    };
    $coll->save($data);
}
