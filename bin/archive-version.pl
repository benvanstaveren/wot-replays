#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Process;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

die 'Usage: archive-version.pl <version number>', "\n" unless($ARGV[0]);

my $version = $ARGV[0];

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;

# archived replays have their files detached and sent to S3, and are marked as archived internally so they
# can no longer be downloaded. 

