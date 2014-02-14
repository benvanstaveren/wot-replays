#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
use WR::Parser;
use WR::Util::Pickle;
use WR::Util::VehicleDescriptor;
use WR::Util::ItemTypes;
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0], cb_gun_shot_count => sub { return 3 } );

print 'num blocks....: ', $parser->num_blocks, "\n";
print 'pickle at.....: ', $parser->pickle_block, "\n";

my $u = $parser->unpack;

if(my $fh = IO::File->new('>unpack.wotreplay')) {
    $fh->binmode(1);
    $u->seek(0, 0);

    while(my $bread = $u->read(my $buffer, 16384)) {
        $fh->write($buffer);
    }
}
