#!/usr/bin/perl
use strict;
use warnings;
use WR::Thunderpush::Server;
use Data::Dumper;

my $p = WR::Thunderpush::Server->new(
    host => 'bacon.wotreplays.org:20000',
    key     => '52ecedef9c81a515f6010000',
    secret  => '52ecee0f9c81a5163c010000',
    );

print Dumper($p->channel_list($ARGV[0]));
