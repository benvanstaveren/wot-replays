#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use JSON::XS;
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;

my $vehicles = {};

my $text = Data::Localize::Gettext->new(path => '../etc/res/raw/lang/*_vehicles.po');

for my $country (qw/china france germany usa ussr/) {
    my $f = sprintf('../etc/res/raw/vehicles/%s.xml', $country);
    print 'processing: ', $f, "\n";
    my $x = XMLin($f);

    foreach my $vid (keys(%$x)) {
        my $data = {};
        my $v = $x->{$vid}->{'level'};
        $v =~ s/^\s+//g;
        $v =~ s/\s+$//g;
        $data->{level} = int($v + 0);

        $data->{is_premium} = (ref($x->{$vid}->{price}) eq 'HASH' && exists($x->{$vid}->{price}->{gold})) ? 1 : 0;

        my $us = $x->{$vid}->{'userString'};
        my ($cat, $ident) = split(/:/, $us);
        $cat =~ s/^#//g;

        $data->{label} = $text->localize_for(lang => $cat, id => $ident);

        $vehicles->{$country}->{$vid} = $data;
    }
}

print JSON::XS->new()->pretty(1)->encode($vehicles);
