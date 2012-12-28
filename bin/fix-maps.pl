#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use MongoDB;
use boolean;

die 'Usage: fix-maps.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $x = XMLin(sprintf('../etc/res/raw/%s/arena.xml', $version));

foreach my $map (keys(%{$x->{map}})) {
    my ($nid, $id) = split(/_/, $map, 2);

    foreach my $size ('32','84') {
        my $oldfile = sprintf('../sites/images.wot-replays.org/maps/%sx%s/%s.jpg', $size, $size, $id);
        my $newfile = sprintf('../sites/images.wot-replays.org/maps/%sx%s/%d_%s.jpg', $size, $size, $nid, $id);

        rename($oldfile, $newfile);
    }
}
