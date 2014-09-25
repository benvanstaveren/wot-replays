#!/usr/bin/perl
use strict;
use warnings;
use lib '../../lib';
use WR::Parser;
use WR::Util::Config;
use WR::Util::Keymaker;
use Data::Dumper;

my $config = WR::Util::Config->load('../../replaysng.conf');
my $keys   = {};
foreach my $type (qw/wot wowp wobs/) {
    $keys->{$type} = WR::Util::Keymaker->make_key($config->get(sprintf('secrets.blowfish.%s', $type)));
}

my $parser = WR::Parser->new(file => $ARGV[0], blowfish_keys => $keys);

print 'Type.......: ', $parser->type, "\n";
print 'Version....: ', $parser->version, "\n";
print 'Upgrade....: ', $parser->upgrade, "\n";

#print 'Meta: ', "\n", Dumper($parser->meta);

