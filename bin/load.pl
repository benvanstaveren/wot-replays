#!/usr/bin/perl
use strict;
use warnings;
use lib qw(.. ../lib lib);

use WR::Query;
use MongoDB;
use boolean;
use Data::Dumper;

$| = 1;

my $mongo  = MongoDB::Connection->new();
my $db     = $mongo->get_database('wot-replays');
my $coll   = $db->get_collection('replays');

my $q = WR::Query->new(
    filter => {
        player => [ qw/Anthalus Staxed/],
        vehicle => 'ussr:KV',
        complete => true,
        related => 123523,
    },
    coll => $coll,
);

print 'Query: ', "\n", Dumper($q->_query);
print 'Exp: ', "\n", Dumper($q->exec()->explain());
print 'Count: ', Dumper($q->exec->count());
