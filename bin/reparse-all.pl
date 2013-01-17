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

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');

my $query = {};

if($ARGV[0] eq 'version') {
    $query->{version} = $ARGV[1];
}

my $rc     = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });

$db->get_collection('track.mastery')->drop(); # drop that

while(my $r = $rc->next()) {
    next unless(defined($r->{file}));
    my $process;
    my $m;
    my $e;
    my $f = sprintf('/home/ben/projects/wot-replays/data/replays/%s', $r->{file});

    try {
        $process = WR::Process->new(file => $f, db => $db, bf_key => WOT_BF_KEY);
        $m = $process->process();
    } catch {
        $e = $_;
    };

    unless($e) {
        $m->{site} = $r->{site}; # copy that over
        $m->{_id}  = $r->{_id}; 
        $m->{file} = $r->{file};
        $db->get_collection('replays')->save($m);
        print ': OK', "\n";
    } else {
        print ': ERROR: ', $e, "\n";
    }
}
