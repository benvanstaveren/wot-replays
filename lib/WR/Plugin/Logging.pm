package WR::Plugin::Logging;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my $self = shift;
    my $app  = shift;

    $app->helper(debug => sub {
        my $self = shift;
        $self->app->log->debug(join(' ', @_));
    });
    $app->helper(error => sub {
        my $self = shift;
        $self->app->log->error(join(' ', @_));
    });
    $app->helper(warning => sub {
        my $self = shift;
        $self->app->log->warning(join(' ', @_));
    });
    $app->helper(info => sub {
        my $self = shift;
        $self->app->log->info(join(' ', @_));
    });
    $app->helper(fatal => sub {
        my $self = shift;
        $self->app->log->fatal(join(' ', @_));
    });
}

1;

