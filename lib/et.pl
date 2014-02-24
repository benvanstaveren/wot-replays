#!/usr/bin/perl
use strict;
use WR::Event;
use Mango;
use Mojo::Log;

my $m = Mango->new('mongodb://localhost:27017');
my $d = $m->db('wot-replays');

my $e = WR::Event->new(
    _debug          => 1,
    db              => $d,
    log             => Mojo::Log->new(level => 'debug'),
    server          => 'sea',
    start_time      => Mango::BSON::bson_time(4320000000),
    end_time        => Mango::BSON::bson_time(1393804800000),
    time_field      => 'game.started',
    registration    => undef,
    input           => {
        matchConditions => {
            'game_type' => 'ctf',
            'stats_kills' => { 'gte' => 1 },
        },
    },
    output          => {
        type    => 'leaderboard',
        config  =>  {
            size        =>  10,
            sort        =>  { kills => -1 },
            generate    =>  { 
                field   => '$stats.kills',
                as      => 'kills',
            },
        }
    },
);

use Data::Dumper;
print Dumper($e->process(0));
