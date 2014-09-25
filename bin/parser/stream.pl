#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "$FindBin::Bin/lib";
use WR::Parser;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use JSON::XS;
use WR::Util::Config;
use WR::Util::Keymaker;
use Mojo::Log;

$| = 1;

my $config = WR::Util::Config->load('../../wr.conf');
my $keys   = {
    wot => WR::Util::Keymaker->make_key($config->get('wot.bf_key')),
};

my $parser = WR::Parser->new(file => $ARGV[0], blowfish_keys => $keys, log => Mojo::Log->new(level => 'debug'));
my $stats  = {};
my $packets = [];
my $total  = 0;
my $j = JSON::XS->new()->allow_blessed(1)->convert_blessed(1)->pretty(1);

try {
    warn 'attempt upgrade', "\n";
    $parser->upgrade(sub {
        my ($parser, $ok, $err) = (@_);
	
	warn 'upgrade says ok ', $ok, ' err ', $err, "\n";
        
        if($ok) {
	    warn 'ok, getting stream', "\n";
            my $stream = $parser->stream;
	    warn 'got: ', $stream. "\n";
            print 'Parser reports as version: ', $parser->version, "\n";
            try {
                while(my $packet = $stream->next) {
                    $stats->{$packet->type}++;
                    push(@$packets, $packet);
                }
            } catch {
                print 'stream stopped: ', $_, "\n";
            };
            print $j->encode($packets);
            foreach my $key (sort { $a <=> $b } (keys(%$stats))) {
                print sprintf('%02x (%d)', $key, $key), ' = ', $stats->{$key}, "\n";
            }
        } else {
            print 'stream not available: ', $err, "\n";
        }
    });
} catch {
    print 'Something bombed big: ', $_, "\n";
};
