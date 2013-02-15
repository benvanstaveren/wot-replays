#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MongoDB;
use WR::Events;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{MONGO} || 'localhost');
my $db     = $mongo->get_database('wot-replays');

my $e = WR::Events->new(db => $db, server => 'sea');

foreach my $event (@{$e->events}) {
    my $count = $e->event($event->{_id})->{cursor}->count;
    print 'event: ', $event->{name}, ', ', $count, ' replays', "\n";

}
