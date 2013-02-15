#!?usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::PlayerProfileData;
use MongoDB;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $ppd = WR::PlayerProfileData->new(
    name    => 'Scrambled',
    id      => 500120062,
    server  => 'eu',
    db      => $db
    );

for(qw/xvm vba wn6/) {
    print $_, ': ', $ppd->efficiency($_), "\n";
}
