#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;

die 'Usage: wiki-maps.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/arenas.po', $version));

my $x = XMLin(sprintf('../etc/res/raw/%s/arena.xml', $version));
foreach my $map (sort { $x->{map}->{$a}->{id} <=> $x->{map}->{$b}->{id} } (keys(%{$x->{map}}))) {
    my ($dummy, $id) = split(/_/, $map, 2);
    my $name = $text->localize_for(lang => 'arenas', id => sprintf('%s/name', $map));

    my $icon = lc($name);
    $icon =~ s/'//g;
    $icon =~ s/\W+/_/g;

    my $slug = lc($name);
    $slug =~ s/\s+/_/g;
    $slug =~ s/'//g;

    print '|-', "\n";
    print sprintf('| %d||%s||%s', $x->{map}->{$map}->{id}, $map, $name), "\n";
}
