package WR::App::Controller::Admin::Moderator::Bothunter;
use Mojo::Base 'WR::App::Controller';
use WR::Analyzer::Bot;

sub index {
    my $self = shift;

    $self->respond(template => 'admin/moderator/bothunter/index', stash => {
        page => { title => 'Moderator Tools - Bot Hunter' },
    });
}

sub process {
    my $self   = shift;
    my $name   = $self->req->param('name');
    my $server = $self->req->param('server');

    $self->render_later;

    my $a = WR::Analyzer::Bot->new(server => $server, player => $name, ua => $self->ua, token => $self->stash('config')->{secrets}->{statterbox});
    $a->analyze(sub {
        my ($a, $err, $score) = (@_);

        if(defined($err)) {
            $self->render(json => { player => $name, score => -1 });
        } else {
            $self->render(json => { player => $name, score => $score });
        }
    });
}

1;
