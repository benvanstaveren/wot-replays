#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use WR::Parser;
use WR::Util::Config;
use WR::Util::Keymaker;
use Mojo::Log;

$| = 1;

my $config = WR::Util::Config->load('../../wr.conf');
my $keys   = {
    wot => WR::Util::Keymaker->make_key($config->get('wot.bf_key')),
};

my $parser = WR::Parser->new(file => $ARGV[0], blowfish_keys => $keys, log => Mojo::Log->new(level => 'debug'));

print 'Type.......: ', $parser->type, "\n";
print 'Version....: ', $parser->version, "\n";
print 'Blocks.....: ', $parser->num_blocks, "\n";
