#!/usr/bin/perl
use strict;
use warnings;
use WR::Statterpush::Server;
use Mojo::IOLoop;
use Mojo::JSON;
use Data::Dumper;

my $p = WR::Statterpush::Server->new(
    host        => 'api.statterbox.com',
    token       => '52fa6dcc9c81a53ec3010000',
    group       => 'wotreplays',
    );

print Dumper($p->send_to_channel(
    'site',
    Mojo::JSON->new->encode({ evt => 'growl', data => { type => 'info', allow_dismiss => Mojo::JSON->true, delay => 10000, text => join(' ', @ARGV) } }),
));
