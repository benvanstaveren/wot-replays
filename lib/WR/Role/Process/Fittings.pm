package WR::Role::Process::Fittings;
use Moose::Role;
use Try::Tiny;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    $res->{vehicle_fittings} = $self->_parser->wot_vehicle_fittings || {};
    return $res;
};

no Moose::Role;
1;
