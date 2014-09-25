package WR::Plugin::Logging;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my $self = shift;
    my $app  = shift;

    $self->helper(debug => sub {
        my $self = shift;
        $self->app->log->debug(join(' ', @_));
    });
    $self->helper(error => sub {
        my $self = shift;
        $self->app->log->error(join(' ', @_));
    });
    $self->helper(warning => sub {
        my $self = shift;
        $self->app->log->warning(join(' ', @_));
    });
    $self->helper(info => sub {
        my $self = shift;
        $self->app->log->info(join(' ', @_));
    });
    $self->helper(fatal => sub {
        my $self = shift;
        $self->app->log->fatal(join(' ', @_));
    });
}

1;

