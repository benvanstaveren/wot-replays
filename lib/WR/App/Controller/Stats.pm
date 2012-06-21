package WR::App::Controller::Stats;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self = shift;
    $self->respond(
        template => 'stats/index',
        stash => {
            page => { title => 'Statistics' },
        },
    );
}


1;
