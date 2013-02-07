package WR::Constants;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);

use constant NATION_NAMES => [(qw/ussr germany usa china france uk/)];
use constant NATION_INDICES => {
    ussr => 0,
    germany => 1,
    usa => 2,
    china => 3,
    france => 4,
    uk => 5
};
    
sub nation_id_to_name {
    return __PACKAGE__->NATION_NAMES->[shift];
}

use constant GAMEPLAY_NAMES => [(qw/ctf domination assault escort ctf2 domination2 assault2/)];
use constant GAMEPLAY_INDICES => {
    ctf => 0,
    domination => 1,
    assault => 2,
    escort => 3,
    ctf2 => 4,
    domination2 => 5,
    assault2 => 6
    };

sub gameplay_id_to_name {
    return __PACKAGE__->GAMEPLAY_NAMES->[shift];
}

sub decode_arena_type_id {
    my $at    = shift;
    my $gp_id = $at >> 16;
    my $m_id  = $at & 32767; 

    return {
        gameplay_type => gameplay_id_to_name($gp_id),
        map_id        => $m_id,
    };
}

our @EXPORT = ();
our @EXPORT_OK = (qw/NATION_NAMES NATION_INDICES nation_id_to_name gameplay_id_to_name decode_arena_type_id/);

1;
