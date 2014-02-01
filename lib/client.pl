#!/usr/bin/perl
use strict;
use warnings;
use WR::Thunderpush::Client;
use Mojo::IOLoop;
use Data::Dumper;

my $p = WR::Thunderpush::Client->new(
    host    => 'bacon.wotreplays.org:20000',
    key     => '52ecedef9c81a515f6010000',
    user    => 'monitor',
    channels => [ 'site' ],
    );

$p->on(connect => sub {
    my ($p, $data) = (@_);

    if($data->{status} == 0) {
        print 'Error connecting: ', $data->{error}, "\n";
    } else {
        print 'Connected!', "\n";
    }
});

$p->on(message => sub {
    my ($p, $msg) = (@_);
    print '[MESSAGE]: ', Dumper($msg), "\n";
});

$p->on(finished => sub {
    my ($p, $data) = (@_);

    print '[FINISHED]: ', Dumper($data), "\n";
});

$p->on(open => sub {
    print '[OPEN]', "\n";
});

$p->on(hearbeat => sub {
    print '[HEARTBEAT]', "\n";
});

$p->connect;

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
