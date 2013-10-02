package WR::BS;
use Mojo::Base 'Mojolicious';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mango;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'bannerserver.conf' });
    $self->secret($config->{app}->{secret});
    $self->defaults(config => $config);

    $self->routes->namespaces([qw/WR::BS/]);

}

1;
