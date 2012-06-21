#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use JSON::XS;
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use Data::Dumper;

die 'Usage: generate-vehicles.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $vehicles = {};

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/*_vehicles.po', $version));

for my $country (qw/china france germany usa ussr/) {
    my $f = sprintf('../etc/res/raw/%s/vehicles/%s.xml', $version, $country);
    print 'processing: ', $f, "\n";
    my $x = XMLin($f);

    foreach my $vid (keys(%$x)) {
        my $data = {};
        my $v = $x->{$vid}->{'level'};
        $v =~ s/^\s+//g;
        $v =~ s/\s+$//g;
        $data->{level} = int($v + 0);

        $data->{is_premium} = (ref($x->{$vid}->{price}) eq 'HASH' && exists($x->{$vid}->{price}->{gold})) ? 1 : 0;

        my $tags = { map { $_ => 1 } (split(/\s+/, $x->{$vid}->{tags})) };
        my $type = 'U';

        # find out what type of tank we're dealing with here
        if(defined($tags->{lightTank})) {
            $type = 'L';
        } elsif(defined($tags->{mediumTank})) {
            $type = 'M';
        } elsif(defined($tags->{heavyTank})) {
            $type = 'H';
        } elsif(defined($tags->{SPG})) {
            $type = 'S';
        } elsif(defined($tags->{'AT-SPG'})) {
            $type = 'T';
        }

        my $us = $x->{$vid}->{'userString'};
        my ($cat, $ident) = split(/:/, $us);
        $cat =~ s/^#//g;

        $data->{label} = $text->localize_for(lang => $cat, id => $ident);
        $data->{type}  = $type;

        $vehicles->{$country}->{$vid} = $data;
    }
}
print JSON::XS->new()->pretty(1)->encode($vehicles);
