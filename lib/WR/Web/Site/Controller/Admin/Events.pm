package WR::Web::Site::Controller::Admin::Events;
use Mojo::Base 'WR::Web::Site::Controller';

sub index {
    my $self = shift;

    $self->respond(template => 'admin/events/index', stash => {
        page => { title => 'Event Manager' },
    });
}

1;
