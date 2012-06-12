package WR::Controller::Account;
use Mojo::Base 'WR::Controller';
use WR::Query;

sub index {
    my $self = shift;

    $self->respond(
        template => 'account/index',
        stash => {
            page => { title => 'Your Account' },
        },
    );
}

1;
