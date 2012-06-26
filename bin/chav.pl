#!/usr/bin/perl
use strict;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $c      = $db->get_collection('replays.chat');

my $cursor = $c->find({ channel => 'unknown' }); 

my $data = {};

while(my $o = $cursor->next()) {
    next unless(defined($o->{source}) && length($o->{source}) > 0);
    $data->{$o->{replay_id}}->[ $o->{sequence} ] = { 
        s => $o->{source},
        b => $o->{body}
    };
}

foreach my $id (keys(%$data)) {
    print $id, "\n";

    foreach my $m (@{$data->{$id}}) {
        print "\t", sprintf('% 20s | %s', $m->{s}, $m->{b}), "\n";
    }
    print "\n\n";
}
