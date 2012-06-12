#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib);

use WR::Parser;
use boolean;
use MongoDB;
use Try::Tiny;
use Data::Dumper;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;

if(my $file = $gfs->find_one({ replay_id => $ARGV[0] })) {
    my $parser = WR::Parser->new();
    $parser->parse($file->slurp);
    print '--[ Chunks ]--------------------------------------------------', "\n";
    print Dumper($parser->chunks);
    print '--[ Mongo Result ]--------------------------------------------', "\n";
    print Dumper($parser->result_for_mongo);
}
