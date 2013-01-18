package WR::App::Controller::Tournament;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self   = shift;

    $self->respond(
        template => 'tournament/view',
        stash    => {
            page => {
                title => 'Tournaments',
            },
        }
    );
}

1;
