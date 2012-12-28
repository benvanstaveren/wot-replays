#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use IO::File;
use File::Basename;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;
my $rc     = $db->get_collection('replays')->find()->sort({ 'site.uploaded_at' => -1 });

while(my $r = $rc->next()) {
    if(my $file = $gfs->find_one({ replay_id => $r->{_id} })) {
        my $filename = $file->info->{filename};
        $filename =~ s/.*\\//g if($filename =~ /\\/);
        print $r->{_id}, ' (', $filename, '): ';

        my $of = sprintf('/storage/replays/%s', $filename);

        if(-e $of) {
            print 'EXISTS', "\n";
        } else {
            if(my $fh = IO::File->new(sprintf('>/storage/replays/%s', $filename))) {
                $fh->binmode(1);
                $fh->write($file->slurp);
                $fh->close;

                $r->{file} = $filename;
                $db->get_collection('replays')->save($r);

                print 'OK', "\n";
            } else {
                print 'ERROR: failed write', "\n";
            }
        }
    }
}
