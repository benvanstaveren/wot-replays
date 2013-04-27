#!/usr/bin/perl
use strict;
use warnings;
use lib qw{../lib};
use WR;
use WR::MR;

my $version = $ARGV[0];

my $map_function = sprintf(q|function() {
    if(this.version == '%s') {
        if(!this.site.download_disabled) {
            emit(this._id, 1);
        }
    }
}|, $version);

my $reduce_function = q|function(k, v) {
var sum = 0;
v.forEach(function(e) {
    sum += e;
}
return sum;
}|;

my $mr = WR::MR->new(
    map    => $map_function,
    reduce => $reduce_function,
);

$mr->execute(   
    'replays',
    sprintf('archive.%s', $version)
    );
