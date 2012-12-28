package WR::App::Controller::Clan;
use Mojo::Base 'WR::App::Controller';
use WR::Query;

sub index {
    my $self = shift;

    $self->respond(
        template => 'clan/index',
        stash => {
            page => { title => 'Clans' },
        },
    );
}

1;
