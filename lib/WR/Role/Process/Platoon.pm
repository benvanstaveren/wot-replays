package WR::Role::Process::Platoon;
use Moose::Role;
use Try::Tiny;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    $res->{platoons} = $self->_parser->wot_player_platoon || {};
    return $res;
};

no Moose::Role;
1;
