package WR::App::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub respond {
    my $self = shift;
    my %args = (@_);
    my $stash = delete($args{'stash'});

    $self->stash(%$stash) if(defined($stash));
    if(my $start = $self->stash('timing.start')) {
        $self->stash('timing_elapsed' => Time::HiRes::tv_interval($start));
    }
    $self->render(%args);
}

1;
