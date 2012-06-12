#!/usr/bin/perl
use strict;
use IO::File;

my $fh = IO::File->new($ARGV[0]);
$fh->binmode(1);

$fh->seek($ARGV[1], 0);

my $r = 0;
my @r = ();
while($r < $ARGV[2]) {
    $fh->seek($ARGV[1] + $r, 0);
    $fh->read(my $buf, 4);
    push(@r, $buf);
    $r += 4;
}

my $o = $ARGV[1];
foreach my $e (@r) {
    print sprintf('%8d: %10u %10u', $o, unpack('L*', $e), unpack('N*', $e)), "\n";
    $o += 4;
}
