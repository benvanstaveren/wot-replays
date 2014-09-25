package WR::Plugin::Fixlog;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Log;

sub register {
    my $self = shift;
    my $app  = shift;

    if(-w $app->home->rel_file('log')) {
        my $mode = $app->mode;
        my $name = ref($app);
        $name =~ s/::/-/g;

        my $file  = $app->home->rel_file(sprintf('log/%s.%s.log', lc($name), $mode));
        my $level = ($mode eq 'development') ? 'debug' : 'info';

        $app->log(Mojo::Log->new(file => $file, level => $level));
    }
}        

1;
