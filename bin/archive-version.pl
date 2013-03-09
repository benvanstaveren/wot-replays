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

die 'Usage: archive-version.pl <version number> [min views] [min downloads] [min likes]', "\n" unless($ARGV[0]);

my $version     = $ARGV[0];
my $minviews    = $ARGV[1] || 10;
my $mindl       = $ARGV[2] || 10; 
my $minlike     = $ARGV[3] || 5;

# the above will keep versions if they have more than minviews views, or more than minviews downloads

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('replays');

my $nv = $version;
$nv =~ s/\D+//g;
$nv += 0;

print 'Archiving version ', $version, ' -> ', $nv, "\n";
my $q = {
    version_numeric => { 
        '$lte' => $nv
    },
    'site.views' => { 
        '$lt' => $minviews, 
    },
    'site.downloads' => {
        '$lt' => $mindl
    },
    'site.like' => {
        '$lt' => $minlike,
    },
};

print 'Query: ', Dumper($q), "\n";

my $cursor = $coll->find($q);


print 'Have ', $cursor->count, ' replays to archive', "\n";
while(my $r = $cursor->next()) {
    $coll->update({ 
        _id => $r->{_id},
    }, 
    { 
        '$set' => {
            'site.download_disabled' => true,
            'site.download_disabled_at' => time(),
        },
    });
    print $r->{_id}->to_string, ': download disabled', "\n";
}
print 'Done', "\n";
