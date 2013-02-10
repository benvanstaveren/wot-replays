#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use WR::ServerFinder;

$| = 1;


my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'site.uploaded_at' => {
        '$lte' => time()
    },
};

my $sf = WR::ServerFinder->new();
my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });
while(my $r = $rc->next()) {
    foreach my $pid (keys(%{$res->{players}})) {
        my $name = $res->{players}->{$pid}->{name};
        if(my $server = $sf->get_server_by_id($pid + 0)) {
            $db->get_collection('cache.server_finder')->save({
                _id => sprintf('%d-%s', $pid + 0, $name),
                user_id     => $pid + 0,
                user_name   => $name,
                server      => $server,
                via         => 'get_server_by_id',
            }, { safe => 1 });
        }
    }
}
