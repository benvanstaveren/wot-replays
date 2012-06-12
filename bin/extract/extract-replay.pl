#!/usr/bin/perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Crypt::Blowfish;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));


my $text = 'this foo';
my $cipher = new Crypt::Blowfish(WOT_BF_KEY);
my $test   = new Crypt::Blowfish('1234567890123456');

my $crypted = $cipher->encrypt($text);
print '[crypted]: ', $crypted, "\n";
my $plain = $test->decrypt($crypted);
print '[plain right]: ', $cipher->decrypt($crypted), ' [wrong]: ', $plain, "\n";


