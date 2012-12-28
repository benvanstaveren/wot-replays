#!/usr/bin/perl
use strict;
use IO::Uncompress::AnyUncompress qw/anyuncompress $AnyUncompressError/;

anyuncompress $ARGV[0] => $ARGV[1] or die 'failed: ', $AnyUncompressError, "\n";
