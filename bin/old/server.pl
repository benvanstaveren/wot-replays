#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib /home/wotreplay/wot-replays/lib);

use WR::ServerFinder;

my $sf = WR::ServerFinder->new();
my $id = $ARGV[0];
my $name = $ARGV[1];

die 'Usage: ', $0, ' <id> <name>', "\n" unless($id && $name);

if(my $res = $sf->find_server($id, $name)) {
    print $name, ' (', $id, '): ', $res, "\n";
} else {
    print $name, ' (', $id, '): not found', "\n";
}
