#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;

$| = 1;


my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'site.uploaded_at' => {
        '$lte' => time()
    },
};

my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });
while(my $r = $rc->next()) {
    if(my $v = $db->get_collection('data.vehicles')->find_one({ _id => $r->{player}->{vehicle}->{full}})) {
        $db->get_collection('replays')->update({ _id => $r->{_id} }, {
            '$set' => { 'player.vehicle.tier' => $v->{level} + 0 },
        });
        print $r->{_id}->to_string, "\n";
    }
}
