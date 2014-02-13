#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use Scalar::Util qw/blessed/;
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use JSON::XS;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $parser = WR::Parser->new(bf_key => WOT_BF_KEY, file => $ARGV[0]);
my $game   = $parser->game();

$game->on(finish => sub {
    my ($game, $reason) = (@_);
    print 'FINISHED: ', Dumper($reason), "\n";
    print Dumper($game->vshells);
    print Dumper($game->vcons);
});

$game->on('game.version' => sub {
    my ($game, $version) = (@_);
    print '[GAME.VERSION]: ', $version, "\n";
});

$game->on('recorder.name' => sub {
    my ($game, $v) = (@_);
    print '[RECORDER.NAME]: ', $v, "\n";
});

$game->on('recorder.id' => sub {
    my ($game, $v) = (@_);
    print '[RECORDER.ID]: ', $v, "\n";
});

$game->on('game.version_n' => sub {
    my ($game, $version) = (@_);
    print '[GAME.VERSION_N]: ', $version, "\n";
});

# change these around
$game->on('arena.vehicle_list' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.VEHICLE_LIST]: ', Dumper($v), "\n";
});

$game->on('arena.vehicle_added' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.VEHICLE_ADDED]: ', Dumper($v), "\n";
});

$game->on('arena.period' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.PERIOD]: ', Dumper($v), "\n";
});

$game->on('arena.statistics' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.STATISTICS]: ', Dumper($v), "\n";
});

$game->on('arena.vehicle_statistics' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.VEHICLE_STATISTICS]: ', Dumper($v), "\n";
});

$game->on('arena.vehicle_killed' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.VEHICLE_KILLED]: ', Dumper($v), "\n";
});

$game->on('arena.avatar_ready' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.AVATAR_READY]: ', Dumper($v), "\n";
});

$game->on('arena.base_points' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.BASE_POINTS]: ', Dumper($v), "\n";
});

$game->on('arena.base_captured' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.BASE_CAPTURED]: ', Dumper($v), "\n";
});

$game->on('arena.team_killer' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.TEAM_KILLER]: ', Dumper($v), "\n";
});

$game->on('arena.vehicle_updated' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.VEHICLE_UPDATED]: ', Dumper($v), "\n";
});

$game->on('arena.initialize' => sub {
    my ($game, $v) = (@_);
    print '[ARENA.INITIALIZE]: ', Dumper($v), "\n";
});

# this comes out of a 0x0b packet, of which we only see 2 
$game->on('setup.map' => sub {
    my ($game, $v) = (@_);
    print '[SETUP.MAP]: ', $v, "\n";
});
    

$game->on('0x08' => sub {
    my ($game, $v) = (@_);

    print '[PACKET 0x08 UNHANDLED SUBTYPE]: ', Dumper($v->to_hash), "\n";
});

$game->on('0x07' => sub {
    my ($game, $v) = (@_);

    print '[PACKET 0x07 UNHANDLED SUBTYPE]: ', Dumper($v->to_hash), "\n";
});

$game->on('player.position' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.POSITION]: ', Dumper($v), "\n";
});

$game->on('player.health' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.HEALTH]: ', Dumper($v), "\n";
});

$game->on('player.viewmode' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.VIEWMODE]: ', Dumper($v), "\n";
});

$game->on('player.track.destroyed' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.TRACK.DESTROYED]: ', Dumper($v), "\n";
});

$game->on('player.orientation.hull' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.ORIENTATION.HULL]: ', Dumper($v), "\n";
});

$game->on('player.slot' => sub {
    my ($game, $v) = (@_);

    print '[PLAYER.SLOT]: ', Dumper($v), "\n";
});

$game->on('unknown' => sub {
    my ($game, $v) = (@_);
    print '[PACKET UNKNOWN]: ', Dumper($v->to_hash), "\n";
});

$game->start();

print 'Final roster: ', Dumper($game->roster), "\n";
