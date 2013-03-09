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
    '$or' => [
        { 'site.download_disabled' => false },
        { 'site.download_disabled' => { '$exists' => false } },
    ],
};
my $cursor = $coll->find($q);
print 'Have ', $cursor->count, ' replays to consider for archiving', "\n";
while(my $r = $coll->find_one($q)) {
    print $r->{_id}->to_string, ': ', $r->{version}, ': ';

    my $views = (defined($r->{site}->{views})) ? $r->{site}->{views} : 0;
    my $likes = (defined($r->{site}->{like})) ? $r->{site}->{like} : 0;
    my $downloads = (defined($r->{site}->{downloads})) ? $r->{site}->{downloads} : 0;

    if($views <= $minviews && $likes <= $minlike && $downloads <= $mindl) {
        $coll->update({ 
            _id => $r->{_id},
        }, 
        { 
            '$set' => {
                'site.download_disabled' => true,
                'site.download_disabled_at' => time(),
            },
        });
        print 'download disabled, ';
        # find the associated file
        my $file = sprintf('/home/wotreplay/wot-replays/data/replays/%s', $r->{file});
        unlink($file);
        print 'file removed', "\n";
    } else {
        print 'keeping', "\n";
    }
}
print 'Done', "\n";
