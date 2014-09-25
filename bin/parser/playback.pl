#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use Scalar::Util qw/blessed/;
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use WR::Util::Config;
use WR::Util::Keymaker;
use Mojo::Log;

$| = 1;

my $config = WR::Util::Config->load('../../wr.conf');
my $keys   = {
    wot => WR::Util::Keymaker->make_key($config->get('wot.bf_key')),
};

my $parser = WR::Parser->new(file => $ARGV[0], blowfish_keys => $keys, log => Mojo::Log->new(level => 'debug'));

$parser->upgrade(sub {
    my ($parser, $ok) = (@_);
    
    if($ok) {
        my $playback   = $parser->playback();

        $playback->on(finish => sub {
            my ($playback, $reason) = (@_);
            print 'FINISHED: ', Dumper($reason), "\n";
            print '--- VCOI ---', "\n", Dumper($playback->vcons_initial);
            print '--- VSHI ---', "\n", Dumper($playback->vshells_initial);
        });

        $playback->on('game.version' => sub {
            my ($playback, $version) = (@_);
            print '[GAME.VERSION]: ', $version, "\n";
        });

        $playback->on('recorder.name' => sub {
            my ($playback, $v) = (@_);
            print '[RECORDER.NAME]: ', $v, "\n";
        });

        $playback->on('recorder.id' => sub {
            my ($playback, $v) = (@_);
            print '[RECORDER.ID]: ', $v, "\n";
        });

        $playback->on('game.version_n' => sub {
            my ($playback, $version) = (@_);
            print '[GAME.VERSION_N]: ', $version, "\n";
        });

        # change these around
        $playback->on('arena.vehicle_list' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.VEHICLE_LIST]: ', Dumper($v), "\n";
        });

        $playback->on('arena.vehicle_added' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.VEHICLE_ADDED]: ', Dumper($v), "\n";
        });

        $playback->on('arena.period' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.PERIOD]: ', Dumper($v), "\n";
        });

        $playback->on('arena.statistics' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.STATISTICS]: ', Dumper($v), "\n";
        });

        $playback->on('arena.vehicle_statistics' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.VEHICLE_STATISTICS]: ', Dumper($v), "\n";
        });

        $playback->on('arena.vehicle_killed' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.VEHICLE_KILLED]: ', Dumper($v), "\n";
        });

        $playback->on('arena.avatar_ready' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.AVATAR_READY]: ', Dumper($v), "\n";
        });

        $playback->on('arena.base_points' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.BASE_POINTS]: ', Dumper($v), "\n";
        });

        $playback->on('arena.base_captured' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.BASE_CAPTURED]: ', Dumper($v), "\n";
        });

        $playback->on('arena.team_killer' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.TEAM_KILLER]: ', Dumper($v), "\n";
        });

        $playback->on('arena.vehicle_updated' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.VEHICLE_UPDATED]: ', Dumper($v), "\n";
        });

        $playback->on('arena.initialize' => sub {
            my ($playback, $v) = (@_);
            print '[ARENA.INITIALIZE]: ', Dumper($v), "\n";
        });

        # this comes out of a 0x0b packet, of which we only see 2 
        $playback->on('setup.map' => sub {
            my ($playback, $v) = (@_);
            print '[SETUP.MAP]: ', $v, "\n";
        });
            

        $playback->on('0x08' => sub {
            my ($playback, $v) = (@_);

            print '[PACKET 0x08 UNHANDLED SUBTYPE]: ', Dumper($v->to_hash), "\n";
        });

        $playback->on('0x07' => sub {
            my ($playback, $v) = (@_);

            print '[PACKET 0x07 UNHANDLED SUBTYPE]: ', Dumper($v->to_hash), "\n";
        });

        $playback->on('player.position' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.POSITION]: ', Dumper($v), "\n";
        });

        $playback->on('player.tank.damaged' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.TANK.DAMAGED]: ', Dumper($v), "\n";
        });

        $playback->on('player.health' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.HEALTH]: ', Dumper($v), "\n";
        });

        $playback->on('player.viewmode' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.VIEWMODE]: ', Dumper($v), "\n";
        });

        $playback->on('player.track.destroyed' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.TRACK.DESTROYED]: ', Dumper($v), "\n";
        });

        $playback->on('player.orientation.hull' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.ORIENTATION.HULL]: ', Dumper($v), "\n";
        });

        $playback->on('player.slot' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.SLOT]: ', Dumper($v), "\n";
        });

        $playback->on('player.chat' => sub {
            my ($playback, $v) = (@_);

            print '[PLAYER.CHAT]: ', Dumper($v), "\n";
        });

        $playback->on('unknown' => sub {
            my ($playback, $v) = (@_);
            print '[PACKET UNKNOWN]: ', Dumper($v->to_hash), "\n";
        });

        $playback->start;

    } else {
        die 'Playback not available', "\n";
    }
});

