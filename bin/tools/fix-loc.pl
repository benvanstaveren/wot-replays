#!/usr/bin/perl
use strict;
use File::Slurp qw/read_file/;
use Data::Dumper;

my @file = read_file($ARGV[0]);

foreach my $line (@file) {
    if($line =~ /\[% h.loc\((.*?)\) %\]/) {
        if($line =~ /(.*?),\s*(.*)/) {
            print 'n: ', $1, ' args: ', $2, "\n";
        } else {
            my $key = $1;
            if($key =~ /^'/) {
                print 'n: ', $key, "\n";
            } else {
                print 'n: [% ', $key, ' %]', "\n";
            }
        }
    }
}
