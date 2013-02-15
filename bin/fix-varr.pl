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

    my $vehicles = $r->{vehicles};
    my $vehicles_a = [];

    foreach my $id (keys(%$vehicles)) {
        $v = $vehicles->{$id};
        $v->{id} = $id;
        push(@$vehicles_a, $v);
    }

    $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { 'vehicles_a' => $vehicles_a } });
    print $r->{_id}->to_string, "\n";
}
