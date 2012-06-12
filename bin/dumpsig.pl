#!/usr/bin/perl
use strict;
use IO::File;

if(my $fh = IO::File->new($ARGV[0])) {
    my $buf;
    $fh->read($buf, 4);
    print 'signature: ', unpack('I*', $buf), "\n";
}
