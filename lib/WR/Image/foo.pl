#!/usr/bin/perl
use Mojo::UserAgent;
use Data::Dumper;
my $ua = Mojo::UserAgent->new;

my $tx = $ua->get('http://images.wotreplays.org/vehicles/100/ussr-object_704.png');
my $res = $tx->success;

if(defined($res)) {
    $res->content->asset->move_to('/tmp/test.png');
}
