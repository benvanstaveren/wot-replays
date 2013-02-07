package WR::Util::TypeComp;
use strict;
use warnings;
require Exporter;

our @ISA = qw(Exporter);

sub parse_int_compact_descr {
    my $int = shift;

    return {
        type_id => $int & 15,
        country => $int >> 4 & 15,
        id      => $int >> 8 & 65535,
    };
}

our @EXPORT = ();
our @EXPORT_OK = (qw/parse_int_compact_descr/);

1;
