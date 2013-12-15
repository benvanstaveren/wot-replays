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
my $coll   = $db->collection('jobs');

my $cursor = $coll->find({ ready => Mango::BSON::bson_true, complete => Mango::BSON::bson_false });
$cursor->sort(Mango::BSON::bson_doc({ priority => 1, ctime => 1 }));

while(my $job = $cursor->next()) {
    print 'ID: ', $job->{_id}, ' PRIO: ', $job->{priority}, "\n";
}

