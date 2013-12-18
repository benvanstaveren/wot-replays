#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR;
use WR::Provider::Panelator;
use WR::Parser;
use Mango;

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
    for my $event ('player.position', 'player.health', 'player.tank.destroyed', 'player.orientation.hull', 'player.chat', 'arena.period', 'player.tank.damaged', 'arena.initialize', 'cell.attention', 'arena.base_points', 'arena.base_captured') {
        $game->on($event => \&addpacket);
    }
    $game->start();
}

my $cursor = $coll->find({ 'has_packets' => Mango::BSON::bson_false })->sort({ 'site.uploaded_at' => -1 })->limit(1);

while(my $replay = $cursor->next()) {
    extract($replay->{file});

    $coll->update({ _id => $replay->{_id} }, { '$set' => { 'has_packets' => Mango::BSON::bson_true }});

    my $seq = 0;
    while(@$packets) {
        my @splice = splice(@$packets, 0, 1000);
        $db->collection('packets')->insert([
            map {
                $_->{_meta} = {
                    replay => $replay->{_id},
                    fields => [ keys(%$_) ],
                    seq    => $seq++,
                };
                $_;
            }
            @splice
        ]);
    }
}
