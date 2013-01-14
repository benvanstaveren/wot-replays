#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use WR::Elastic; 

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $rc     = $db->get_collection('replays')->find()->sort({ 'site.uploaded_at' => -1 });

my $elastic = WR::Elastic->new();

$elastic->setup if($ARGV[0] eq 'setup');

while(my $r = $rc->next()) {
    $elastic->index_replay($r);
}
