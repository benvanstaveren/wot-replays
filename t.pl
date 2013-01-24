#!?usr/bin/perl
use strict;
use warnings;
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new();
$ua->get('http://worldoftanks-sea.com/uc/tournaments/')->res->dom('a.b-past-tournaments-link')->each(sub {
    my $e = shift;

    print $e, "\n";
});
