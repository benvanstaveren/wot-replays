#!/usr/bin/perl
use strict;
use File::Slurp qw/read_file/;
use IO::File;
use JSON::XS;

my $j       = JSON::XS->new();
my $raw     = read_file($ARGV[0]);
my $packets = $j->decode($raw);

my $init = $packets->[0];

my $lastpos = {};

my $map_id      = $init->{map_id};
my $gameplay_id = $init->{gameplay_id};
my $bonus_type  = $init->{bonus_type};

# we just dump raw positions and leave it up to the site end to convert this to 
# the proper subcell values 
foreach my $p (@$packets) {
    if(defined($p->{position})) {
        $lastpos->{$p->{id}} = $p->{position};
        print $j->encode({ map_id => $map_id, gameplay_id => $gameplay_id, bonus_type => $bonus_type, x => $p->{position}->[0], y => $p->{position}->[2], is_death => 0, is_damage => 0 }), "\n";
    }
    if(defined($p->{destroyer})) {
        my $dl = $lastpos->{$p->{destroyed}};
        next unless(defined($dl));
        print $j->encode({ map_id => $map_id, gameplay_id => $gameplay_id, bonus_type => $bonus_type,  x => $dl->[0], y => $dl->[2], is_damage => 0, is_death => 1 }), "\n";
    }
    if(defined($p->{health}) && defined($p->{source})) {
        my $dl = $lastpos->{$p->{id}};
        next unless(defined($dl));
        print $j->encode({ map_id => $map_id, gameplay_id => $gameplay_id, bonus_type => $bonus_type, x => $dl->[0], y => $dl->[2], is_death => 0, is_damage => 1 }), "\n";
    }
}
