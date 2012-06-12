package WR::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub respond {
    my $self = shift;
    my %args = (@_);
    my $stash = delete($args{'stash'});

    $self->stash(%$stash) if(defined($stash));
    $self->render(%args);
}

1;
