#!/usr/bin/perl
use strict;
use warnings;
use Mango;
use Mojo::IOLoop;

my $m = Mango->new('mongodb://localhost:27017/');
my $d = $m->db('wot-replays');
my $c = $d->collection('jobs');

my $cursor = $c->find();
$cursor->tailable(1);

while(my $doc = $cursor->next) {
    use Data::Dumper;
    warn 'doc: ', Dumper($doc), "\n";
}
