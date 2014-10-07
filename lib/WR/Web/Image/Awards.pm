package WR::Web::Image::Awards;
use Mojo::Base 'Mojolicious::Controller';
use File::Path qw/make_path/;
use Imager;
use Try::Tiny qw/try catch/;

sub get_big_image {
    my $self        = shift;
    my $str         = shift;
    my $cb          = shift;

    $self->debug('get_big_image using ', $self->config->{statterbox}->{server}, ' as app token for statterbox');

    $self->ua->post('http://api.statterbox.com/wot/encyclopedia/achievements' => form => {
        application_id => $self->config->{'statterbox'}->{'server'},
        cluster        => 'asia',
        fields         => 'image_big',
    } => sub {
        my ($ua, $tx) = (@_);
        if(my $res = $tx->success) {
            if($res->json('/status') eq 'ok') {
                my $url = $res->json->{data}->{$str}->{image_big};
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
    my $vstr = $self->stash('award');

    $self->render_later;

    if($size == 180) {
        $self->get_big_image($vstr => sub {
            my ($content, $error) = (@_);

            if(defined($error)) {
                $self->render(text => 'ERROR FETCHING FROM WG', status => 500);
            } else {
                $content->move_to(sprintf('%s/icon/awards/180/%s.png', $self->app->home->rel_dir('public'), $vstr));
                $self->reply->static(sprintf('icon/awards/180/%s.png', $vstr));
            }
        });
    } else {
        # check if we have the full size, or at least the 64 sized one (for mark of mastery)
        if(-e sprintf('%s/icon/awards/180/%s.png', $self->app->home->rel_dir('public'), $vstr) || -e sprintf('%s/icon/awards/64/%s.png', $self->app->home->rel_dir('public'), $vstr)) {
            $self->render_thumbnail($vstr => $size);
        } else {
            $self->get_big_image($vstr => sub {
                my ($content, $error) = (@_);

                if(defined($error)) {
                    $self->render(text => 'ERROR FETCHING FROM WG', status => 500);
                } else {
                    $content->move_to(sprintf('%s/icon/awards/180/%s.png', $self->app->home->rel_dir('public'), $vstr));
                    $self->render_thumbnail($vstr => $size);
                }
            });
        }
    }
}

sub render_thumbnail {
    my $self = shift;
    my $vstr = shift;
    my $size = shift;
    my $rv   = 0;

    try {
        my $img = Imager->new;
        my $src = (-e sprintf('%s/icon/awards/180/%s.png', $self->app->home->rel_dir('public'), $vstr)) 
            ? sprintf('%s/icon/awards/180/%s.png', $self->app->home->rel_dir('public'), $vstr)
            : sprintf('%s/icon/awards/64/%s.png', $self->app->home->rel_dir('public'), $vstr);
        $img->read(file => $src);
        my $path = sprintf('%s/icon/awards/%d/', $self->app->home->rel_dir('public'), $size);
        make_path($path) unless(-e $path);
        my $thumb = $img->scale(xpixels => $size);
        $thumb->write(file => sprintf('%s/%s.png', $path, $vstr));
        $rv = 1;
    } catch {
        $rv = 0;
    };

    if($rv == 0) {
        $self->render(text => 'ERROR CREATING THUMBNAIL', status => 500);
    } else {
        $self->reply->static(sprintf('icon/awards/%d/%s.png', $size, $vstr));
    }
}

1;
