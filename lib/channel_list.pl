#!/usr/bin/perl
use strict;
use warnings;
use WR::Statterpush::Server;
use Mojo::IOLoop;
use Mojo::JSON;
use Data::Dumper;

my $p = WR::Statterpush::Server->new(
    host        => 'localhost:3000',
    token       => '52fa6116907e1347ac010000',
    group       => 'wotreplays',
    );

$p->channel_list(
    $ARGV[0],
    sub {
        my ($sp, $res) = (@_);

        print Dumper($res);
        exit(0);
    }
);

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
