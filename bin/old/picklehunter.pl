#!/usr/bin/perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Python::Serialize::Pickle::InlinePython;
use IO::File;
use Try::Tiny qw/try catch/;

my $fh = IO::File->new('lakeville.wotreplay.unpacked');
$fh->binmode(1);

my $offset = $ARGV[0];

my $out = IO::File->new('>temp.d');
$fh->seek($offset, 0);
while(my $bread = $fh->read(my $buf, 4096)) {
    $out->write($buf);
}
$out->close();

my $p = Python::Serialize::Pickle::InlinePython->new('temp.d');
my $s = 0;
while(my $data = $p->load()) {
    my $fh = IO::File->new(sprintf('>lakeville.pickles/%s-%s.data', $offset, $s));
    $fh->print(Dumper($data));
    $s++;
}

exit(0);
