#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR;
use Mango;

$| = 1;

my $mango  = Mango->new($ENV{'MONGO'} || 'mongodb://localhost:27017');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('replays');

my $cursor = $coll->find({ 'game.bonus_type' => $ARGV[0] + 0 });
my $total = $cursor->count;
$cursor->sort({ 'site.uploaded_at' => -1 });
my $done  = 0;
while(my $replay = $cursor->next()) {
    print 'ID: ', $replay->{_id}, ' DIGEST: ', $replay->{digest}, "\n";
    my $job = {
        _id => $replay->{digest},
        uploader    => undef,
        ready       => Mango::BSON::bson_true,
        reprocess   => Mango::BSON::bson_true,
        complete    => Mango::BSON::bson_false,
        status      => 0,
        error       => undef,
        replayid    => $replay->{_id},
        ctime       => Mango::BSON::bson_time,
        status_text => [],
        data        => {
            file    => sprintf('%s/%s', '/home/wotreplay/wot-replays/data/replays', $replay->{file}),
            desc    => $replay->{site}->{description},
            visible => ($replay->{site}->{visible}) ? 1 : 0,
            file_base => $replay->{file},
        },
        priority    => 1000,
    });
}
