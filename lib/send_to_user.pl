#!/usr/bin/perl
use strict;
use warnings;
use WR::Statterpush::Server;
use Mojo::IOLoop;
use Mojo::JSON;
use Data::Dumper;

my $p = WR::Statterpush::Server->new(
    host        => 'localhost:3000',
    token       => '52fa6dcc9c81a53ec3010000',
    group       => 'wotreplays',
    );

$p->send_to_user(
    $ARGV[0],
    Mojo::JSON->new->encode({ evt => 'growl', data => { type => 'info', allow_dismiss => Mojo::JSON->true, delay => 10000, text => join(' ', @ARGV) } }),
    sub {
        my ($sp, $res) = (@_);

        print Dumper($res);
        exit(0);
    }
);

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
