#!/usr/bin/perl
use strict;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $c      = $db->get_collection('replays');
my $cc     = $db->get_collection('replays.chat');
my $data   = {};

my $cursor = $c->find({ chatProcessed => true })->sort({ 'site.uploaded_at' => 1 });
while(my $r = $cursor->next()) {
    $data->{$r->{_id}} = [ $cc->find({ channel => 'unknown', replay_id => $r->{_id} })->sort({ sequence => 1 })->all() ];
}
foreach my $id (keys(%$data)) {
    print $id, "\n";

    foreach my $m (@{$data->{$id}}) {
        print "\t", sprintf('% 20s | %s', $m->{source}, $m->{body}), "\n";
    }
    print "\n\n";
}
