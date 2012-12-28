#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

die 'Usage: delete-version.pl <version number>', "\n" unless($ARGV[0]);

my $version = $ARGV[0];

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;

my $cursor = $db->get_collection('replays')->find({ version => $version});
while(my $o = $cursor->next()) {
    $gfs->delete($o->{file});
    $db->get_collection('replays')->update({ _id => 

    



