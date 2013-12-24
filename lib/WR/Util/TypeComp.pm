package WR::Util::TypeComp;
use strict;
use warnings;
require Exporter;

our @ISA = qw(Exporter);

use constant TYPE_NAMES => [qw/reserved vehicle vehicleChassis vehicleTurret vehicleGun vehicleEngine vehicleFuelTank vehicleRadio tankman optionalDevice shell equipment/];

sub parse_int_compact_descr {
    my $int = shift;

    return {
        type_id => $int & 15,
        country => $int >> 4 & 15,
        id      => $int >> 8 & 65535,
    };
}

sub type_id_to_name {
    my $type = shift;

    return TYPE_NAMES->[$type] || 'unknown';
}

our @EXPORT = ();
our @EXPORT_OK = (qw/parse_int_compact_descr type_id_to_name TYPE_NAMES/);

1;
