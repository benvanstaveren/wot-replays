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
$cursor->fields({ digest => 1 });
my $done  = 0;
while(my $replay = $cursor->next()) {
    $db->collection('jobs')->update({ 
        _id => $replay->{digest} 
    }, { 
        '$set' => {
            locked      => Mango::BSON::bson_false,
            ready       => Mango::BSON::bson_false,
            complete    => Mango::BSON::bson_false,
            reprocess   => Mango::BSON::bson_false,
            priority    => 1000,
            status_text => [],
        },
    });
    printf "% 6d / %6d                             \r", ++$done, $total;
}
print "\n";
