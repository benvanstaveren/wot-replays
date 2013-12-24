package WR::Constants;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);

use constant NATION_NAMES => [(qw/ussr germany usa china france uk japan/)];
use constant NATION_INDICES => {
    ussr => 0,
    germany => 1,
    usa => 2,
    china => 3,
    france => 4,
    uk => 5,
    japan => 6
};
    
sub nation_id_to_name { return __PACKAGE__->NATION_NAMES->[shift]; }

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

sub gameplay_id_to_name { return __PACKAGE__->GAMEPLAY_NAMES->[shift]; }

sub decode_arena_type_id {
    my $at    = shift;
    my $gp_id = $at >> 16;
    my $m_id  = $at & 32767; 

    return {
        gameplay_type => gameplay_id_to_name($gp_id),
        map_id        => $m_id,
    };
}

sub encode_arena_type_id {
    my $gameplay_id = shift;
    my $map_id      = shift;

}

use constant VEHICLE_DEVICE_TYPE_NAMES => [qw/engine ammoBay fuelTank radio track gun turretRotator surveyingDevice/];
use constant VEHICLE_TANKMAN_TYPE_NAMES => [qw/commander driver radioman gunner loader/];

use constant ARENA_UPDATE => {
    'VEHICLE_LIST'          =>  1,
    'VEHICLE_ADDED'         =>  2,
    'PERIOD'                =>  3,
    'STATISTICS'            =>  4,
    'VEHICLE_STATISTICS'    =>  5,
    'VEHICLE_KILLED'        =>  6,
    'BASE_POINTS'           =>  8,
    'BASE_CAPTURED'         =>  9,
    'TEAMKILLER'            =>  10,
    'VEHICLE_UPDATED'       =>  11,
    };

use constant ARENA_UPDATE_IDX => [ 'dummy', map { __PACKAGE__->ARENA_UPDATE->{$_} } (keys(%{__PACKAGE__->ARENA_UPDATE})) ];

sub arena_update {
    return __PACKAGE__->ARENA_UPDATE_IDX->[shift];
}

our @EXPORT = ();
our @CONSTANT_VALUES = (qw/NATION_NAMES NATION_INDICES VEHICLE_DEVICE_TYPE_NAMES VEHICLE_TANKMAN_TYPE_NAMES ARENA_UPDATE ARENA_UPDATE_IDX/);
our @METHOD_VALUES = (qw/nation_id_to_name gameplay_id_to_name decode_arena_type_id arena_update/);
our @EXPORT_OK = (@CONSTANT_VALUES, @METHOD_VALUES);

1;
