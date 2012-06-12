#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib);

package WR::Reparser;

sub new { 
    my $class = shift;
    my $self = { 
        c => shift,
    };
    return bless($self, 'WR::Reparser' );
}

sub db {
    my $self = shift;
    my $name = shift;

    return $self->{c}->get_database($name);
}

package main;

use WR::Parser;
use boolean;
use MongoDB;
use Try::Tiny;
use Data::Dumper;
use WR::Util;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $rp     = WR::Reparser->new($mongo);

my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;
my $rc     = $db->get_collection('replays')->find();

$db->get_collection('track.mastery')->drop(); # drop that

while(my $r = $rc->next()) {
    if(my $file = $gfs->find_one({ replay_id => $r->{_id} })) {
        print $r->{_id}, ': ';
        my $parser = WR::Parser->new();
        $parser->parse($file->slurp);
        my $m = $parser->result_for_mongo;
        $m->{file} = $file->info->{_id};
        $m->{site} = $r->{site}; # copy that over

        unless(defined($m->{site}->{uploaded_at})) {
            $m->{site}->{uploaded_at} = $file->info->{_id}->get_time();
        }

        my $mastery = $m->{player}->{statistics}->{mastery} || 0;

        # find out whether this match awards mastery or not
        $m->{player}->{statistics}->{mastery} = WR::Util::award_mastery($rp, $m->{player}->{name}, $m->{player}->{vehicle}->{full}, $mastery) if(defined($m->{player}->{statistics}) && $mastery > 0);

        # get the player server
        $m->{player}->{server} = WR::Util::server_finder($rp, $m->{player}->{id}, $m->{player}->{name});

        # see if we need to process team kills
        if($m->{complete}) {
            if(scalar(@{$m->{player}->{statistics}->{teamkill}->{log}}) > 0) {
                foreach my $entry (@{$m->{player}->{statistics}->{teamkill}->{log}}) {
                    if(my $name = WR::Util::user_finder($rp, $entry->{targetID}, $m->{player}->{server})) {
                        my $vid = $m->{vehicles_hash_name}->{$name}->{id};
                        $m->{player}->{statistics}->{teamkill}->{hash}->{$vid} = $entry;
                    }
                }
            }
        }

        $db->get_collection('replays')->save($m);


        print ': OK', "\n";
    } else {
        print $r->{_id}, ': NOT FOUND', "\n";
    }
}
