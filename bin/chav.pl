#!/usr/bin/perl
use strict;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $c      = $db->get_collection('replays.chat');

my $cursor = $c->find({ channel => 'unknown' })->
