#!/usr/bin/perl
use strict;
use warnings;
use lib qw|./lib|;
use WR::Parser;

my $key = join('', map { chr(hex($_)) } (split(/\s/, "DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF")));

my $p = WR::Parser->new(
    bf_key => $key,
    traits => [qw/
        LL::File
        Data::Reader
        Data::Decrypt
        Data::Attributes
        Data::Chat
    /],
    file => $ARGV[0]
);

print 'Version......: ', $p->wot_version, "\n";
print 'Player team..: ', $p->find_player_team($p->get_my_name), "\n";
my $messages = $p->chat_messages;

print '-- chat message dump -----------------', "\n";
foreach my $message (@{$p->chat_messages}) {
    print 'Source......: ', $message->{source}, "\n";
    print 'Target......: ', $message->{channel}, "\n";
    print 'Body........: ', $message->{body}, "\n";
    print "\n";
}

sub hexdump {
    my $str    = shift;

    my @s = split(//, $str);
    my @a;
    my @b;
    my @c;

    foreach my $c (@s) {
        push(@a, sprintf('%03x', ord($c)));
        push(@b, sprintf('%03d', ord($c)));
        if(ord($c) > 31 && ord($c) < 127) {
            push(@c, sprintf('% 3s', $c));
        } else {
            push(@c, '-?-');
        }
    }

    my $hd;
    $hd .= "\t" . join(' ', @a) . "\n";
    $hd .= "\t" . join(' ', @b) . "\n";
    $hd .= "\t" . join(' ', @c) . "\n";

    return $hd;
}

