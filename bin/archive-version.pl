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

die 'Usage: archive-version.pl <version number> [min views] [min downloads]', "\n" unless($ARGV[0]);

my $version = $ARGV[0];

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;
my $coll   = $db->get_collection('replays');

my $acoll   = $db->get_collection(sprintf('archive-%s.replays', $version));

my $file_coll  = $db->get_collection('fs.files');
my $chunk_coll = $db->get_collection('fs.chunks');

my $afile_coll = $db->get_collection(sprintf('archive-%s.files', $version));
my $achunk_coll = $db->get_collection(sprintf('archive-%s.chunks', $version));


# archived stuff is basically moved 1:1 to acoll and agfs

my $cursor = $coll->find({ version => $version});
my $total = $cursor->count();
my $i = 0;

while(my $o = $cursor->next()) {
    printf('Processing: %05d of %05d', ++$i, $total);
    print "\r";
 
    $acoll->save($o);

    # find the file 
    my $f = $file_coll->find_one({ _id => $o->{file} });
    $afile_coll->save($f);
    my $fc = $chunk_coll->find({ files_id => $f->{_id} });
    while(my $c = $fc->next()) {
        $achunk_coll->save($c);
    }

    $chunk_coll->remove({ files_id => $f->{_id} });
    $file_coll->remove({ _id => $f->{_id} });
    $coll->remove({ _id => $o->{_id} });
}
