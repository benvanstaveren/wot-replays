#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use JSON::XS;
use Data::Localize;
use Data::Localize::Gettext;
use File::Slurp qw/read_file/;
use MongoDB;
use boolean;

die 'Usage: mongo-components.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/*_vehicles.po', $version));

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('data.components');

my $nations = {
    ussr => 0,
    germany => 1,
    usa => 2,
    china => 3,
    france => 4,
    uk => 5,
    japan => 6,
};

$| = 1;

my $j = JSON::XS->new();

for my $country (qw/japan china france germany usa ussr uk/) {
    for my $comptype (qw/chassis engines fueltanks guns radios turrets/) {
        my $f = sprintf('../etc/res/raw/%s/components/%s_%s.json', $version, $country, $comptype);
        warn 'processing: ', $f, "\n";
        my $d = read_file($f);
        warn 'read', "\n";
        my $x = $j->decode($d);
        warn 'decode', "\n";

        my $ids = (defined($x->{ids})) ? $x->{ids} : $x;

        foreach my $name (keys(%$ids)) {
            warn 'name: ', $name, "\n";
            next if($name eq 'text');
            my $id = $x->{ids}->{$name};
            next if($id eq '' || $id == 0);
            my $data = {
                _id => sprintf('%s_%s_%d', $country, $comptype, $id),
                country         => $country,
                component       => $comptype,
                component_id    => $id,
            };

            if(defined($x->{shared}) && ref($x->{shared}) && defined($x->{shared}->{$name})) {
                warn 'is shared', "\n";
                my $us   = $x->{shared}->{$name}->{userString};
                my $desc = $x->{shared}->{$name}->{description};

                warn 'label', "\n";
                $data->{label} = (defined($us)) 
                    ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $us) 
                    : (defined($name)) 
                        ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name)
                        : sprintf('nolabel:%s', $name);

                warn 'desc', "\n";
                $data->{description} = (defined($desc)) ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $desc) : undef;
                
                if($comptype eq 'guns') {
                    $data->{shots} = [ keys(%{$x->{shared}->{$name}->{shots}}) ];
                }
            } else {
                warn 'label', "\n";
                $data->{label} = $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name);
                warn 'desc', "\n";
                $data->{description} = '';
            }

            $coll->save($data);
            
        }
    }

    my $f = sprintf('../etc/res/raw/%s/components/%s_%s.json', $version, $country, 'shells');
    warn 'processing: ', $f, "\n";
    my $d = read_file($f);
    my $x = $j->decode($d);

    foreach my $name (keys(%$x)) {
        my $shell = $x->{$name};
        my $typecomp = 10 + ($nations->{$country} << 4);
        $typecomp = (($shell->{id} + 0) << 8) + $typecomp;

        my $data = {
            %$shell,
            _id             => $typecomp,
            country         => $country,
            component       => 'shells',
        };
        $data->{component_id} = delete($data->{id});

        if(ref($data->{price}) eq 'HASH') {
            $data->{price} = { unit => 'gold', amount => $data->{price}->{text} + 0 };
        } else {
            $data->{price} = { unit => 'silver', amount => $data->{price} + 0 };
        }

        my $us = delete($data->{userString});
        my $desc = delete($data->{description});
        $data->{label} = (defined($us)) 
            ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $us) 
            : (defined($name))
                ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name)
                : sprintf('nolabel:%s', $name);

        $data->{description} = (defined($desc)) ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $desc) : '';
        $coll->save($data, { safe => 1 }) and warn 'saved: ', $name, "\n";
    }
}
