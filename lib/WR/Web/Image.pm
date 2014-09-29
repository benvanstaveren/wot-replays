package WR::Web::Image;
use Mojo::Base 'Mojolicious';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mango;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wr-image.conf' });
    $self->secrets([ $config->{app}->{secret} ]); 

    $self->plugin('WR::Plugin::Logging');
    $self->plugin('WR::Plugin::Mango' => $config->{mongodb}); 
    $self->plugin('WR::Plugin::Preloader' => [ 'vehicles' ]);


    $self->routes->namespaces([qw/WR::Web::Image/]);
    my $root = $self->routes;

    my $vehicles = $root->under('/vehicles');
        $vehicles->route('/:size/:vehicle_string')->to('vehicles#index');

    my $awards = $root->under('/icon/awards');
        $awards->route('/:size/:award')->to('awards#index');
}

1;
