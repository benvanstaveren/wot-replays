#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use MongoDB;
use Try::Tiny;
use IO::File;
use Tie::IxHash;
use Data::Dumper;
use File::Slurp qw/read_file/;

$| = 1;

die 'Usage: $0 <mr folder> <output collection>', "\n" unless($ARGV[1]);


die 'No map.js', "\n" unless(-e sprintf('%s/map.js', $ARGV[0]));
die 'No reduce.js', "\n" unless(-e sprintf('%s/reduce.js', $ARGV[0]));

my $map = read_file(sprintf('%s/map.js', $ARGV[0]));
my $reduce = read_file(sprintf('%s/reduce.js', $ARGV[0]));


my $mongo  = MongoDB::Connection->new({ host => 'mongodb://hwn-01.blockstackers.net:27017' });
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('replays');

my $job = Tie::IxHash->new(
    mapreduce => 'replays',
    map       => $map,
    reduce    => $reduce,
    out       => {
        replace => $ARGV[1]
    }
);

print Dumper($db->run_command($job));

