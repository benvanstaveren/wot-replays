package WR::Controller::Clan;
use Mojo::Base 'WR::Controller';
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
