#!/usr/bin/perl
use WR::Constants qw/decode_arena_type_id/;

use Data::Dumper;
print Dumper(decode_arena_type_id(16));
