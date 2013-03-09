#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use boolean;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'site.uploaded_at' => {
        '$lte' => time()
    },
    'version_numeric' => {
        '$exists' => false,
    },
};

my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });
while(my $r = $rc->next()) {
    my $nv = $r->{version};
    $nv =~ s/\D+//g;
    $nv += 0;

    $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { 'version_numeric' => $nv } });
    print $r->{_id}->to_string, ' ', $r->{version}, ' -> ', $nv, "\n";
}
