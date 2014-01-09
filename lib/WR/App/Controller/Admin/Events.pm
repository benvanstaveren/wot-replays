package WR::App::Controller::Admin::Events;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    $self->respond(template => 'admin/events/index', stash => {
        page => { title => 'Event Manager' },
    });
}

1;
