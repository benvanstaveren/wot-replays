package WR::App::Controller;
use Mojo::Base 'Mojolicious::Controller';
use IO::File;

sub respond {
    my $self = shift;
    my %args = (@_);
    my $stash = delete($args{'stash'});

    $self->stash(%$stash) if(defined($stash));
    if(my $start = $self->stash('timing.start')) {
        $self->stash('timing_elapsed' => Time::HiRes::tv_interval($start));
    }
    $self->render(%args);
    return 1;

    # unused for the time being, let's try full dynamic mode again

    if(defined($self->stash('cachereplay')) && $self->stash('cachereplay') == 1) {
        my $parts = $self->req->url->path->parts;
        my $fragment = $parts->[1];
        $fragment .= '.html' unless($fragment =~ /\.html$/);
        my $filename = sprintf('%s/%s', $self->stash('config')->{paths}->{pages}, $fragment);
        if(my $fh = IO::File->new(sprintf('>%s', $filename))) {
            $fh->print($self->res->body);
            $fh->close;
        }
    }

    return 1;
}

1;
