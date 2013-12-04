#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR;
use WR::Provider::Panelator;
use Mango;

$| = 1;

my $mango  = Mango->new($ENV{'MONGO'} || 'mongodb://localhost:27017');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('replays');
my $p = WR::Provider::Panelator->new(db => $db);


my $cursor = $coll->find()->sort({ 'site.uploaded_at': -1 });
my $total = $cursor->count;
my $done  = 0;
while(my $replay = $cursor->next()) {
    if(!defined($replay->{game}->{map_extra})) {
        $replay->{game}->{map_extra} = $p->generate_map_extra($replay);
    }
    $replay->{panel} = $p->panelate($replay);
    $coll->save($replay);

    printf "% 6d / %6d                             \r", ++$done, $total;
}
print "\n";
