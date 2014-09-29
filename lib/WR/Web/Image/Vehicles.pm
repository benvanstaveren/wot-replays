package WR::Web::Image::Vehicles;
use Mojo::Base 'Mojolicious::Controller';
use File::Path qw/make_path/;
use Imager;
use Try::Tiny qw/try catch/;

sub get_big_image {
    my $self        = shift;
    my $typecomp    = shift;
    my $cb          = shift;

    $self->debug('get_big_image using ', $self->config->{statterbox}->{server}, ' as app token for statterbox');

    $self->ua->post('http://api.statterbox.com/wot/encyclopedia/tankinfo' => form => {
        application_id => $self->config->{'statterbox'}->{'server'},
        cluster        => 'asia',
        tank_id        => $typecomp,
        fields         => 'image',
    } => sub {
        my ($ua, $tx) = (@_);
        if(my $res = $tx->success) {
            $self->debug('get_big_image have res: ', $res->body);
            if($res->json('/status') eq 'ok') {
                my $url = $res->json->{data}->{$typecomp}->{image};
                $self->debug('get_big_image status ok, final url: ', $url);
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

    $self->render_later;

    my ($country, $vid) = split(/-/, $vstr, 2);

    # unfortunately, the WG API doesn't allow for pulling up info by way of vehicle strings, so we have to go
    # and resolve it to an ID first, but we can do this from the vehicles quickdb 
    my $typecomp = $self->data_vehicles->get(name_lc => $vid)->{typecomp};

    $self->debug('want ', $size, ' size, vstr: ', $vstr, ' as typecomp: ', $typecomp);

    if($size == 100) {
        $self->get_big_image($typecomp => sub {
            my ($content, $error) = (@_);

            if(defined($error)) {
                # render the no-such-bloody-size thing
                $self->reply->static('vehicles/100/noimage.png');
            } else {
                $content->move_to(sprintf('%s/vehicles/100/%s.png', $self->app->home->rel_dir('public'), lc($vstr)));
                $self->reply->static(sprintf('vehicles/100/%s.png', $vstr));
            }
        });
    } else {
        # check if we have the full size
        if(-e sprintf('%s/vehicles/100/%s.png', $self->app->home->rel_dir('public'), lc($vstr))) {
            $self->render_thumbnail($vstr => $size);
        } else {
            $self->get_big_image($typecomp => sub {
                my ($content, $error) = (@_);

                if(defined($error)) {
                    $self->render_noimage($size);
                } else {
                    $content->move_to(sprintf('%s/vehicles/100/%s.png', $self->app->home->rel_dir('public'), lc($vstr)));
                    $self->render_thumbnail($vstr => $size);
                }
            });
        }
    }
}

sub render_noimage {
    my $self = shift;
    my $size = shift;
    my $rv   = 0;

    try {
        my $img = Imager->new;
        $img->read(file => sprintf('%s/vehicles/100/noimage.png', $self->app->home->rel_dir('public')));
        my $path = sprintf('%s/vehicles/%d/', $self->app->home->rel_dir('public'), $size);
        make_path($path) unless(-e $path);
        my $thumb = $img->scale(xpixels => $size);
        $thumb->write(file => sprintf('%s/noimage.png', $path));
        $rv = 1;
    } catch {
        $rv = 0;
    };

    if($rv == 0) {
        $self->render(text => 'ERROR CREATING THUMBNAIL', status => 500);
    } else {
        $self->reply->static(sprintf('vehicles/%d/noimage.png', $size));
    }
}

sub render_thumbnail {
    my $self = shift;
    my $vstr = shift;
    my $size = shift;
    my $rv   = 0;

    try {
        my $img = Imager->new;
        $img->read(file => sprintf('%s/vehicles/100/%s.png', $self->app->home->rel_dir('public'), lc($vstr)));
        my $path = sprintf('%s/vehicles/%d/', $self->app->home->rel_dir('public'), $size);
        make_path($path) unless(-e $path);
        my $thumb = $img->scale(xpixels => $size);
        $thumb->write(file => sprintf('%s/%s.png', $path, lc($vstr)));
        $rv = 1;
    } catch {
        $rv = 0;
    };

    if($rv == 0) {
        $self->render(text => 'ERROR CREATING THUMBNAIL', status => 500);
    } else {
        $self->reply->static(sprintf('vehicles/%d/%s.png', $size, lc($vstr)));
    }
}

1;
