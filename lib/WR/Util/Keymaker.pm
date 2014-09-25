package WR::Util::Keymaker;
use strict;
use warnings;

sub make_key {
    my $pkg    = shift;
    my $string = shift;
    return undef unless(defined($string) && length($string) > 0);
    return join('', map { chr(hex($_)) } (split(/\s/, $string)));
}

1;
