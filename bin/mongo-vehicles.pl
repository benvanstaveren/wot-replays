#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use XML::Simple;
use Data::Localize;
use Data::Localize::Gettext;
use MongoDB;
use boolean;

die 'Usage: mongo-vehicles.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/*_vehicles.po', $version));

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.vehicles');


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

        $data->{is_premium} = (ref($x->{$vid}->{price}) eq 'HASH' && exists($x->{$vid}->{price}->{gold})) ? true : false;

        my $us = $x->{$vid}->{'userString'};
        my ($cat, $ident) = split(/:/, $us);
        $cat =~ s/^#//g;

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

        $data->{label} = $text->localize_for(lang => $cat, id => $ident);
        $data->{_id} = sprintf('%s:%s', $country, $ident);
        $data->{country} = $country;
        $data->{name} = $ident;
        $data->{description} = $text->localize_for(lang => $cat, id => sprintf('%s_descr', $ident));
        $data->{type} = $type;

        $coll->save($data);
    }
}
