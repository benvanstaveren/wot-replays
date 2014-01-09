package WR::App::Controller::Admin::Language;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    $self->respond(template => 'admin/language/index', stash => {
        page => { title => $self->loc('admin.language.page.title') }
    });
}

1;
