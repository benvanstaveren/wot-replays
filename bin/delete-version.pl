#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use boolean;
use MongoDB;
use Try::Tiny;
use Data::Dumper;

$| = 1;

die 'Usage: delete-version.pl <version number>', "\n" unless($ARGV[0]);

my $version     = $ARGV[0];

# the above will keep versions if they have more than minviews views, or more than minviews downloads

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('replays');

print 'Deleting version ', $version, "\n";
my $cursor = $coll->find({ 'version' => $version });

print 'Have ', $cursor->count, ' replays to delete';
while(my $r = $cursor->next()) {
    print $r->{_id}->to_string, ': ';

    $coll->remove({ _id => $r->{_id} });
    my $file = sprintf('/home/wotreplay/wot-replays/data/replays/%s', $r->{file});
    unlink($file);
    print 'deleted', "\n";
}
print 'Done', "\n";
