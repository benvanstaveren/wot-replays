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
            '@bonustype'    => { in => [ 1, 3, 4, 7 ] },
            '@kills'        => { gte => 1 },
            '@damageDealt'  => { gte => 750 },
            '@vehicle'      => { in => [ 'usa:M18_Hellcat' ] },
        },
    },
    output          => {
        type    => 'leaderboard',
        config  =>  {
            size        =>  5,
            sort        =>  { replays => -1 },
            generate    =>  { 
                field   => 1,
                as      => 'replays',
            },
        }
    },
);

use Data::Dumper;
print Dumper($e->process(0));
