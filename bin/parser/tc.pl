#!/usr/bin/perl
use strict;
use warnings;
use lib qw(lib/);
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use WR::Constants qw/nation_id_to_name/;
use Data::Dumper;

my $d = parse_int_compact_descr($ARGV[0] + 0);

print 'Descriptor: ', Dumper($d), "\n";
print 'Country: ', nation_id_to_name($d->{country}) || 'invalid', "\n";
print 'Type...: ', type_id_to_name($d->{type_id}), "\n";
