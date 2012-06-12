#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use MongoDB;
use boolean;

my $text = Data::Localize::Gettext->new(path => '../../etc/res/raw/lang/arenas.po');

my $x = XMLin('../../etc/res/raw/arena.xml');

foreach my $map (keys(%{$x->{map}})) {
    my ($nid, $id) = split(/_/, $map, 2);
    my $langid = sprintf('%s/name', $map);
    my $name = $text->localize_for(lang => 'arenas', id => $langid);

    print 'id: ', $id, ' label: ', $name, "\n";
}
