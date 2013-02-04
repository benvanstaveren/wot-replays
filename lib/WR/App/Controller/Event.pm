package WR::App::Controller::Event;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self   = shift;

    $self->respond(
        template => 'event/index',
        stash    => {
            page => {
                title => 'Events',
            },
        }
    );
}

sub index_server {
    my $self = shift;
    my $s    = $self->stash('server');


    $self->respond(
        template => 'event/server',
        stash    => {
            page => {
                title => sprintf('%s - Events', $self->app->wr_res->servers->get($s, 'label_long')),
            },
        }
    );

}

1;
