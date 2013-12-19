package WR::API::Auto;
use Mojo::Base 'Mojolicious::Controller';

# doesn't do anything yet, might be used later to implement blocking and banning
sub index {
    my $self = shift;

    $self->res->headers->header('Access-Control-Allow-Origin' => '*');
    $self->res->headers->header('Access-Control-Allow-Headers' => '*');

    return 1;
}

1;
