package WR::Role::Process::Fittings;
use Moose::Role;
use Try::Tiny;
use WR::Util::ItemTypes;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    my $it = WR::Util::ItemTypes->new();

    $res->{vehicle_fittings} = $self->_parser->wot_vehicle_fittings || {};
    $res->{component_attributes} = {
        gun => {
            shot_count => $self->_parser->cb_gun_shot_count->(
                $self->_parser->player_country, # FIXME FIXME relies on block 1 
                $res->{vehicle_fittings}->{$self->_parser->wot_player_name}->{data}->{gun}
            ),
        },
    };

    return $res;
};

no Moose::Role;
1;
