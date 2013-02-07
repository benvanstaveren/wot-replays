#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use Try::Tiny;
use Data::Dumper;
use File::Path qw/make_path/;
use File::Copy qw/move/;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'site.uploaded_at' => {
        '$lte' => time()
    },
};

my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });

my $path = (-e '/home/ben') 
    ? '/home/ben/projects/wot-replays/data/replays'
    : '/home/wotreplay/wot-replays/data/replays';

use DateTime;

while(my $r = $rc->next()) {
    print $r->{file}, ': ';
    print 'no file', "\n" and next unless(defined($r->{file}));

    my $dt = DateTime->from_epoch(epoch => $r->{_id}->get_time);

    my $_path = sprintf('%s/%s', $path, $dt->strftime('%Y/%m/%d'));
    make_path($_path);

    my $new_file = sprintf('%s/%s', $dt->strftime('%Y/%m/%d'), $r->{file});
    my $dst_file = sprintf('%s/%s', $_path, $r->{file});

    if(-e $dst_file) {
        $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { file => $new_file } });
        print 'already', "\n";
    } else {
        move(sprintf('%s/%s', $path, $r->{file}) => $dst_file);
        $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { file => $new_file } });
        print 'moved', "\n";
    }
}
