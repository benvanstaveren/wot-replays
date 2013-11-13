#!/usr/bin/perl
use strict;
use warnings;
use Mango;
use WR::Provider::WN7;
use Mojo::IOLoop;

my $mango = Mango->new('mongodb://localhost:27017/');
my $db    = $mango->db('wot-replays');

my $p = WR::Provider::WN7->new(db => $db);
my $id = $ARGV[0] + 0;

$p->fetch_one($id => sub {
    exit(0);
});

Mojo::IOLoop->start unless(Mojo::IOLoop->is_running);
