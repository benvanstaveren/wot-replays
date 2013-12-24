#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
use WR::Parser;
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0], cb_gun_shot_count => sub { return 3 } );

if($parser->num_blocks < 2) {
    print 'Incomplete replay? Dumping blocks', "\n";
    for(my $b = 0; $b < $parser->num_blocks; $b++) {
        print Dumper($parser->get_block($b + 1));
    }
} else {
    my $u = $parser->get_battle_result;
    print Dumper($u);
}
