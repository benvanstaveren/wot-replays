#!?usr/bin/perl
use WR::Imager;

my $i = WR::Imager->new();

$i->create(map => '23_westfeld', vehicle => 'usa-m18_hellcat', map_name => 'Westfield', vehicle_name => 'M18 Hellcat', player => 'Scrambled',
    result => 'victory',
);
