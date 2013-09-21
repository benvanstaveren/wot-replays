#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use Data::Localize;
use Data::Localize::Gettext;
use MongoDB;
use boolean;
use JSON::XS;
use File::Slurp qw/read_file/;

die 'Usage: mongo-maps.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/arenas.po', $version));

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.maps');

my $j = JSON::XS->new;
my $d = read_file(sprintf('../etc/res/raw/%s/arenas.json', $version));
my $x = $j->decode($d);
foreach my $map (@{$x->{map}}) {
    my ($dummy, $id) = split(/_/, $map->{name}, 2);
    my $name = $text->localize_for(lang => 'arenas', id => sprintf('%s/name', $map->{name}));

    my $slug = lc($name);
    $slug =~ s/\s+//g;
    $slug =~ s/'//g;

    my $data = {
        _id             => $map->{name},
        name_id         => $id,
        numerical_id    => $map->{id} + 0,
        label           => $name,
        slug            => $slug,
        icon            => lc(sprintf('%s.png', $map->{name})),
    };

    warn 'id: ', $map->{name}, ' name: ', $name, ' slug: ', $slug, ' name_id: ', $id, "\n";

    $coll->save($data);
}
