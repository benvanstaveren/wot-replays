#!/usr/bin/perl
use strict;
use warnings;
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

my $url = sprintf('http://statterbox.com/api/v1/%s/clan?server=%s&player=%s', '5299a074907e1337e0010000', $ARGV[0], $ARGV[1]);

use Data::Dumper;
if(my $tx = $ua->get($url)) {
    if(my $res = $tx->success) {
        print Dumper($res->json);
    } else {
        print 'REQ ERROR', "\n";
    }
} else {
    print 'NO TX', "\n";
}

