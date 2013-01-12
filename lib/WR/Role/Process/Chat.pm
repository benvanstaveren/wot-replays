package WR::Role::Process::Chat;
use Moose::Role;
use Try::Tiny;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    $res->{chat} = $self->_parser->chat_messages || [];
    return $res;
};

no Moose::Role;
1;
