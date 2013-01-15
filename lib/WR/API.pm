package WR::API;
use Mojo::Base 'Mojolicious';


# this is a bit cheesy but... 
use FindBin;
use lib "$FindBin::Bin/../lib";

use WR;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wr.conf' });
    $config->{wot}->{bf_key} = join('', map { chr(hex($_)) } (split(/\s/, $config->{wot}->{bf_key})));

    $self->secret($config->{app}->{secret});

    $self->plugin('mongodb', {
        host => $config->{mongodb},
    });

    $self->defaults(config => $config);

    $self->routes->namespaces([qw/WR::API/]);

    my $root = $r->bridge('/')->to('auto#index');
    my $apiroot  = $root->under('/v1');
        my $api = $apiroot->bridge('/')->to('v1#check_token');
            my $data = $api->under('/data');
                $data->route('/equipment')->to('v1#data', type => 'equipment');
                $data->route('/consumables')->to('v1#data', type => 'consumables');
                $data->route('/vehicles')->to('v1#data', type => 'vehicles');
                $data->route('/components')->to('v1#data', type => 'components');

            $api->route('/parse')->to('v1#parse');

}

1;
