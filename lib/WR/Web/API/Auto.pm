package WR::Web::API::Auto;
use Mojo::Base 'Mojolicious::Controller';

# doesn't do anything yet, might be used later to implement blocking and banning
sub index {
    my $self = shift;
    return 1;
}

1;
