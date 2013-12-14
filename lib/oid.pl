#!/usr/bin/perl
use strict;
use Data::Dumper;
use WR::OpenID;

my $o = WR::OpenID->new(region => 'asia', schema => 'https', nb => 0);

$o->return_to('http://www.wotreplays.org/openid/return');

my $check_url = $o->checkid_immediate('https://asia.wargaming.net/id/');

print 'going to: ', $check_url, "\n";
