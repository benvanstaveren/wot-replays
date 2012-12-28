#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use JSON::XS;

die 'Usage: generate-maps.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/arenas.po', $version));
my $a = [];
my $x = XMLin(sprintf('../etc/res/raw/%s/arena.xml', $version));

foreach my $map (keys(%{$x->{map}})) {
    my ($nid, $id) = split(/_/, $map, 2);
    my $name = $text->localize_for(lang => 'arenas', id => sprintf('%s/name', $map));

    push(@$a, {
        _id => $id,
        label => $name,
    });
}

print JSON::XS->new()->pretty(1)->encode($a);
