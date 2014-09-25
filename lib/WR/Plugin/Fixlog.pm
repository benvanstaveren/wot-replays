package WR::Plugin::Fixlog;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my $self = shift;
    my $app  = shift;

    if(-w $app->home->rel_file('log')) {
        my $mode = $app->mode;
        my $name = ref($app);
        $name =~ s/::/-/g;
        $self->log->path($app->home->rel_file(sprintf('log/%s.%s.log', lc($name), $mode)));
        $self->log->level('info') unless $mode eq 'development';
    }
}        

1;
