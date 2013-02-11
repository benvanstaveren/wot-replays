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
    'site.uploaded_at' => {
        '$lte' => time()
    },
};

my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });

print 'battle results for: ', $rc->count(), ' replays', "\n";
print 'query:',"\n",Dumper($query),"\n";

my $path = (-e '/home/ben') 
    ? '/home/ben/projects/wot-replays/data/replays'
    : '/home/wotreplay/wot-replays/data/replays';

while(my $r = $rc->next()) {
    print 'no file', "\n" and next unless(defined($r->{file}));
    my $process;
    my $m;
    my $e;
    my $f = sprintf('%s/%s', $path, $r->{file});

    next if($db->get_collection('battleresults')->find({ replay_id => $r->{_id} })->count() > 0);
    my $br;

    try {
        $process = WR::Process->new(file => $f, db => $db, bf_key => WOT_BF_KEY);
        $m = $process->process();
        $br = $process->pickledata;
    } catch {
        $e = $_;
    };

    unless($e) {
        $db->get_collection('battleresults')->save({
            replay_id => $r->{_id},
            battle_result => $br
        });
        print ': OK', "\n";
    } else {
        print ': ERROR: ', $e, "\n";
    }
}
