#!/usr/bin/perl
use strict;
use File::Slurp qw/read_file/;
use IO::File;
use JSON::XS;
use File::Find;

# have to use File::Find
my @filelist = ();

find(sub {
    /^.*\.json\z/s
    && push(@filelist, $File::Find::name);
}, $ARGV[0]);

my $mongo_import;
open($mongo_import, '|/usr/bin/mongoimport -d wtr-heatmaps -c raw_location') || die ('Could not open pipe to mongoimport', "\n");

my $j       = JSON::XS->new();

sub export {
    my $hash = shift;
    my $def  = shift;

    foreach my $key (keys(%$def)) {
        $hash->{$key} = $def->{$key};
    }
    print $mongo_import $j->encode($hash), "\n";
}

foreach my $file (@filelist) {
    my $raw     = read_file($file);
    my $packets = $j->decode($raw);
    my $init = $packets->[0];
    my $lastpos     = {};   # well, there is that... 
    my $lasthealth  = {};   # this one's a bit harder on account of not knowing what someones' full health is 
                            # based on the initial vehicle setup, it's not in the packets, but we can fiddle that 
                            # in later versions by adding a few "pseudo" packets with interpreted information

    my $map_id      = $init->{map_id};
    my $gameplay_id = $init->{gameplay_id};
    my $bonus_type  = $init->{bonus_type};
    my $defaults    = { map_id => $map_id, gameplay_id => $gameplay_id, bonus_type => $bonus_type };
    
    foreach my $p (@$packets) {
        if(defined($p->{position})) {
            $lastpos->{$p->{id}} = $p->{position};
            export({ is => 'location', x => $p->{position}->[0], y => $p->{position}->[2] }, $defaults);
        }
        if(defined($p->{destroyer})) {
            my $dl = $lastpos->{$p->{destroyed}};
            next unless(defined($dl));
            export({ is => 'death', x => $dl->[0], y => $dl->[2] }, $defaults);
        }
        if(defined($p->{health})) {
            if(defined($p->{source})) {
                if(my $dl = $lastpos->{$p->{id}}) {
                    export({ is => 'damage_r', x => $dl->[0], y => $dl->[2] }, $defaults);
                }
                if(my $dl = $lastpos->{$p->{source}}) {
                    export({ is => 'damage_d', x => $dl->[0], y => $dl->[2] }, $defaults);
                }
            }
        }
    }
}
