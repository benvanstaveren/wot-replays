#!?usr/bin/perl
use WR::Imager;

my $i = WR::Imager->new();

$i->create(
    map     => '23_westfeld',
    vehicle => 'usa-m18_hellcat', 
    result => 'victory',
    credits => 123450,
    xp      => 12345,
    kills   => 1,
    spotted => 8,
    damaged => 7,
    player  => 'Scrambled',
    clan    => 'TDC-O',
    destination => '/tmp/replay.png',
);
