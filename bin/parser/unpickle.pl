#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib/';

use WR::Util::Pickle;
use Data::Dumper;
use IO::File;

my $fh = IO::File->new($ARGV[0]) || die 'Unable to open ', $ARGV[0], ': ', $!, "\n";
$fh->binmode(1);
my $buf = '';

while(my $bread = $fh->read(my $tbuf, 1024)) {
    $buf .= $tbuf;
}

$fh->close;

print Dumper(WR::Util::Pickle->new(data => $buf)->unpickle);
    

