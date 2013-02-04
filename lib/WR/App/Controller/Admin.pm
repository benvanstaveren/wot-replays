package WR::App::Controller::Admin;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub bridge {
    my $self = shift;

    if($self->is_user_authenticated) {
        warn 'auth', "\n";
        if($self->has_role($self->current_user => 'admin') == 1) {
            warn 'has role', "\n";
            return 1;
        } else {
            warn 'no role', "\n";
            $self->redirect_to('/') and return 0;
        }
    } else {
        warn 'no auth', "\n";
        $self->redirect_to('/') and return 0;
    }
}

sub index {
    my $self = shift;

    $self->respond(
        template => 'admin/index',
        stash => {
            page    => { title => 'Admin' },
        },
    );
}

1;
