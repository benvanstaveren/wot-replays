package WR::Image::Vehicles;
use Mojo::Base 'Mojolicious::Controller';
use WR::Util::Thumbnail;

sub get_big_image {
    my $self        = shift;
    my $typecomp    = shift;
    my $cb          = shift;

    $self->ua->post('http://api.statterbox.com/wot/encyclopedia/tankinfo' => form => {
        application_id => $self->config->{'statterbox'}->{'server'},
        cluster        => 'asia',
        tank_id        => $typecomp,
        fields         => 'image',
    } => sub {
        my ($ua, $tx) = (@_);
        if(my $res = $tx->success) {
            if($res->json('/status') eq 'ok') {
                my $url = $res->json->{data}->{$typecomp}->{image};
                $self->ua->get($url => sub {
                    my ($ua, $tx) = (@_);
                    if(my $res = $tx->success) {
                        return $cb->($res->content->asset, undef);
                    } else {
                        return $cb->(undef, 'request failed');
                    }
                });
            } else {
                return $cb->(undef, $res->json('/error'));
            }
        } else {
            return $cb->(undef, 'request failed');
        }
    });
}

sub index {
    my $self = shift;
    my $size = $self->stash('size');
    my $vstr = $self->stash('vehicle_string');

    my ($country, $vid) = split(/-/, $vstr, 2);

    # unfortunately, the WG API doesn't allow for pulling up info by way of vehicle strings, so we have to go
    # and resolve it to an ID first, but we can do this from the vehicles quickdb 
    my $typecomp = $self->data_vehicles->get(name_lc => $vid);

    # find out if we have our full size image or not

    $self->get_big_image($typecomp => sub {
        my ($content, $error) = (@_);

        if(defined($error)) {
            $self->render(text => 'ERROR FETCHING FROM WG', status => 500);
        } else {
            $content->move_to(sprintf('%s/vehicles/100/%s.png', $self->app->home->rel_dir('public/images'), lc($vstr)));
            $self->render_static(sprintf('vehicles/100/%s.png', $vstr));
        }
    });
}

1;
