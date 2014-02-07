#!/usr/bin/perl
use strict;
use warnings;
use Mojo::UserAgent;
use Mango;

my $mango  = Mango->new($ENV{'MONGO'} || 'mongodb://localhost:27017');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('accounts');

my $ua = Mojo::UserAgent->new;

my $url = sprintf('http://statterbox.com/api/v1/%s/clan?server=%s&player=%s', '5299a074907e1337e0010000', $ARGV[0], $ARGV[1]);

use Data::Dumper;
if(my $tx = $ua->get($url)) {
    if(my $res = $tx->success) {
        if(my $clan = $res->json->{data}->{$ARGV[1]}) {
            $coll->update({ _id => sprintf('%s-%s', $ARGV[0], $ARGV[1]) }, { '$set' => { clan => $clan }});
            print 'UPDATED', "\n";
        }
    } else {
        print 'REQ ERROR', "\n";
    }
} else {
    print 'NO TX', "\n";
}

