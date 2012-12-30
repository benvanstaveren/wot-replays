#!/usr/bin/perl
use strict;
use warnings;
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new();
my @images = ();

my $u = Mojo::URL->new($ARGV[0]);
my $res = $ua->get($u)->res;

foreach my $img ($res->dom('a img')->each) {
    if($img->attrs('width') == 160 && $img->attrs('height') == 100) {
        push(@images, $u->clone->path($img->attrs('src')));
    }
}

foreach my $iu (@images) {
    my $res = $ua->get($iu)->res;
    my $fn = lc($iu);
    $fn =~ s/.*\///; 

    print "$iu -> $fn\n";
    $res->content->asset->move_to(sprintf('%s/%s', $ARGV[1], $fn));
}
