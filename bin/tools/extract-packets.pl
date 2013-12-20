#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR;
use WR::Provider::Panelator;
use WR::Parser;
use Mango;
use JSON::XS;
use File::Path qw/make_path/;

$| = 1;

my $mango  = Mango->new($ENV{'MONGO'} || 'mongodb://localhost:27017');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('replays');

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $packets = [];
sub addpacket {
    my ($game, $v) = (@_);
    push(@$packets, $v);
}

sub extract {
    my $file = shift;
    my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => sprintf('/home/wotreplay/wot-replays/data/replays/%s', $file));

    my $game   = $parser->game();

    # these are the ones we're interested in for the time being, other packets will not be added 

    for my $event ('player.position', 'player.health', 'player.tank.destroyed', 'player.orientation.hull', 'player.chat', 'arena.period', 'player.tank.damaged', 'arena.initialize', 'cell.attention', 'arena.base_points', 'arena.base_captured') {
        $game->on($event => \&addpacket);
    }

    $game->start();
}

my $cursor = $coll->find();
my $total = $cursor->count;
$cursor->sort({ 'site.uploaded_at' => -1 })->limit(50);
my $done  = 0;
my $j     = JSON::XS->new();

while(my $replay = $cursor->next()) {
    extract($replay->{file});

    # packets are hashbucketed at 7 
    my $bucket = join('/', split(//, substr($replay->{_id} . '', 0, 7)));
    my $path   = sprintf('/home/wotreplay/wot-replays/data/packets/%s', $bucket);
    my $filename = sprintf('%s/%s.json', $path, $replay->{_id} . '');

    make_path($path) unless(-e $path);

    if(my $fh = IO::File->new($filename, '>')) {
        $fh->print($j->encode($packets));
        $fh->close;

        $replay->{packets} = sprintf('%s/%s.json', $bucket, $replay->{_id} . '');
    } else {
        $replay->{packets} = undef;
    }
    $coll->save($replay);
    $packets = [];

    printf "% 6d / %6d                             \r", ++$done, $total;
}
print "\n";
