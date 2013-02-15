#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use Try::Tiny;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'site.uploaded_at' => {
        '$lte' => time()
    },
    'vehicles_a' => { '$exists' => 1 },
};

my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });
my $count = $rc->count;

while($count > 0) {
    my $r = $rc->next;

    next unless(defined($r));

    print $r->{_id}->to_string, "\n";
    my $vehicles = $r->{vehicles};
    my $vehicles_a = [];

    foreach my $id (keys(%$vehicles)) {
        my $v = $vehicles->{$id};
        $v->{id} = $id;
        push(@$vehicles_a, $v);
    }

    try {
        $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { 'vehicles_a' => $vehicles_a } });
        $count--;
    } catch {
        $mongo = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
        $db = $mongo->get_database('wot-replays');
        $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });
        $count = $rc->count;
        print '-- exception caught, reconnected, ', $rc->count, ' replays left', "\n";
    };
}
