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
use Data::Dumper;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $query = {
    'player.vehicle.label' => { '$exists' => false },
};

my $path = (-e '/home/ben') 
    ? '/home/ben/projects/wot-replays/data/replays'
    : '/home/wotreplay/wot-replays/data/replays';

if(my $r = $db->get_collection('replays')->find_one($query)) {
    unless(defined($r->{file})) {
        $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { 'player.vehicle.label' => 'corrupt replay' } });
        print 'no file', "\n" and next;
    }
    my $process;
    my $m;
    my $e;
    my $f = sprintf('%s/%s', $path, $r->{file});

    try {
        $process = WR::Process->new(file => $f, db => $db, bf_key => WOT_BF_KEY);
        $m = $process->process();
    } catch {
        $e = $_;
    };

    $process = undef;

    unless($e) {
        $m->{site} = $r->{site}; # copy that over
        $m->{_id}  = $r->{_id}; 
        $m->{file} = $r->{file};
        $db->get_collection('replays')->save($m, { safe => 1 });
        print $r->{_id}, ': OK', "\n";
    } else {
        print $r->{_id}, ': ERROR: ', $e, "\n";
    }
    exit(0);
}
exit(1);
