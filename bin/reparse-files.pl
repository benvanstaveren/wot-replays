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

my $path = (-e '/home/ben') 
    ? '/home/ben/projects/wot-replays/data/replays'
    : '/home/wotreplay/wot-replays/data/replays';

opendir(my $dir, $path);
my @files = readdir($dir);
closedir($dir);

foreach my $file (@files) {
    next unless($file =~ /\.wotreplay$/);
    print $file, ': ';
    
    my $process;
    my $m;
    my $e;
    my $f = sprintf('%s/%s', $path, $file);

    try {
        $process = WR::Process->new(file => $f, db => $db, bf_key => WOT_BF_KEY);
        $m = $process->process();
    } catch {
        $e = $_;
    };

    $m->{site}->{visible} = true;
    $m->{site}->{uploaded_at} = time();

    $process = undef;

    unless($e) {
        $db->get_collection('replays')->save($m, { safe => 1 });
        print ': OK', "\n";
    } else {
        print ': ERROR: ', $e, "\n";
    }
}
