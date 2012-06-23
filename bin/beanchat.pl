#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Parser;
use boolean;
use MongoDB;
use Try::Tiny;
use Beanstalk::Client;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new();
my $bs = Beanstalk::Client->new({ server => 'localhost' });

while(1) {
    my $job = $bs->reserve;
    my $id  = bless({ value => $job->data }, 'MongoDB::OID');
    print '[job]: received for ', $job->data, "\n";

    $bs->delete($job->id);
}

