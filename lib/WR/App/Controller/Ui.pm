package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use boolean;
use Cache::File;
use Net::OpenID::Consumer;
use URI::Escape;
use LWPx::ParanoidAgent;
use Time::HiRes qw/gettimeofday tv_interval/;
use Filesys::DiskUsage::Fast qw/du/;

sub faq {
    shift->respond(template => 'faq', stash => { page => { title => 'Frequently Asked Questions' } });
}

sub donate {
    shift->respond(template => 'donate', stash => { page => { title => 'Why Donate?' } });
}

sub about {
    shift->respond(template => 'about', stash => { page => { title => 'About' } });
}

sub credits {
    shift->respond(template => 'credits', stash => { page => { title => 'Credits' } });
}

sub index {
    my $self    = shift;
    my $start   = [ gettimeofday ];
    my $newest  = [];
    my $replays = [];

    # here we generate a bunch of hoohah 
    $self->render_later;

    # no need for a count
    my $cursor = $self->model('replays')->find({ 'site.visible' => Mango::BSON::bson_true })->sort({ 'site.uploaded_at' => -1 })->limit(15)->fields({ panel => 1, site => 1 })->all(sub {
        my ($c, $e, $replays) = (@_);
        $self->respond(template => 'index', stash => {
            replays         => $replays || [],
            page            => { title => 'Home' },
            timing_query    => tv_interval($start),
        });
    });
}

sub xhr_du {
    my $self = shift;

    my $bytes = du($self->stash('config')->{paths}->{replays});
    
    $self->render(
        json => {
            bytes => $bytes,
            megabytes => sprintf('%.2f', $bytes / (1024 * 1024)),
            gigabytes => sprintf('%.2f', $bytes / (1024 * 1024 * 1024)),
        }
    );
}

sub xhr_ds {
    my $self = shift;

    $self->render_later;

    $self->get_database->command(Mango::BSON::bson_doc('dbStats' => 1, 'scale' => (1024 * 1024)) => sub {
        my ($db, $err, $doc) = (@_);

        if(defined($doc)) {
            my $n = {};
            for(qw/dataSize storageSize indexSize/) {
                $n->{$_} = $doc->{$_};
            }
            $self->render(json => { ok => 1, data => $n });
        } else {
            $self->render(json => { ok => 0 });
        }
    });
}

sub nginx_post_action {
    my $self = shift;
    my $file = $self->req->param('f');
    my $stat = $self->req->param('s');

    $self->render_later;

    if(defined($stat) && lc($stat) eq 'ok') {
        my $real_file = substr($file, 1); # because we want to ditch that leading slash
        $self->model('replays')->update({ file => $real_file }, { '$inc' => { 'site.downloads' => 1 } } => sub {
            $self->render(text => 'OK');
        });
    } else {
        $self->render(text => 'OK');
    }
}

sub xhr_qs {
    my $self = shift;

    $self->render_later;
    $self->model('jobs')->find({ ready => Mango::BSON::bson_true, complete => Mango::BSON::bson_false })->count(sub {
        my ($c, $e, $d) = (@_);

        if(defined($d)) {
            $self->render(json => { ok => 1, count => $d });
        } else {
            $self-render(json => { ok => 0 });
        }
    });
}

sub do_logout {
    my $self = shift;

    # logging out just means we want to jack up the session cookie
    $self->session('openid' => undef);

    $self->respond(template => 'login/form', stash => {
        page => { title => 'Login' },
        notify  => { type => 'notify', text => 'You logged out successfully', sticky => 0, close => 1 },
    });
}

sub do_login {
    my $self = shift;
    my $s    = $self->req->param('s');
    my $f    = $self->req->param('f');

    if(defined($s)) {
        # fix for the sea -> asia move
        $s = 'asia' if($s eq 'sea');
        $self->session('after_openid' => $f);
        my %params = @{ $self->req->params->params };
        my $my_url = $self->req->url->base;
        my $csr = Net::OpenID::Consumer->new(
            ua              => LWPx::ParanoidAgent->new,
            args            => \%params,
            consumer_secret => $self->app->secret,
            required_root   => $my_url,
            debug           => 1,
        );
        my $url = sprintf('http://%s.wargaming.net/', $s);
        if(my $claimed_identity = $csr->claimed_identity($url)) {
            my $check_url = $claimed_identity->check_url(
                return_to      => qq{$my_url/openid/return},
                trust_root     => qq{$my_url/},
                delayed_return => 1,
            );
            return $self->redirect_to($check_url);
        } else {
            $self->app->log->debug(sprintf('OpenID error: %s', $csr->err));
            $self->session(
                'notify' => { type => 'error', text => sprintf('OpenID Error: %s', $csr->err),  close => 1, sticky => 1 },
            );
            $self->redirect_to('/');
        }
    } else {
        $self->respond(template => 'login/form', stash => {
            page => { title => 'Login' },
        });
    }
}

sub openid_return {
    my $self = shift;
    my $my_url = $self->req->url->base;
    my %params = @{ $self->req->query_params->params };

    while ( my ( $k, $v ) = each %params ) {
        $params{$k} = URI::Escape::uri_unescape($v);
    }

    my $csr = Net::OpenID::Consumer->new(
        ua              => LWPx::ParanoidAgent->new,
        args            => \%params,
        consumer_secret => $self->app->secret,
        required_root   => $my_url
    );

    $self->render_later;

    $csr->handle_server_response(
        not_openid => sub {
            $self->respond(template => 'login/form', stash => {
                page    => { title => 'Login' },
                notify  => { type => 'error', text => 'A message was received that was not an OpenID message', sticky => 1, close => 1 },
            });
        },
        setup_needed => sub {
            return $self->redirect_to($params{'openid.user_setup_url'});
        },
        cancelled => sub {
            $self->respond(template => 'login/form', stash => {
                page    => { title => 'Login' },
                notify  => { type => 'error', text => 'You cancelled the signin process', sticky => 0, close => 1 },
            });
        },
        verified => sub {
            my $vident = shift;
            my $url    = $vident->url;

            $self->session(
                'openid' => $vident->url,
                'notify' => { type => 'info', text => 'Login successful', close => 1 },
            );

            if(my $f = $self->session('after_openid')) {
                $self->redirect_to(sprintf('/%s', $f));
            } else {
                $self->redirect_to('/');
            }
        },
        error => sub {
            my $err = shift;

            $self->respond(template => 'login/form', stash => {
                page    => { title => 'Login' },
                notify  => { type => 'error', text => sprintf('OpenID Error: %s', $err), sticky => 0, close => 1 },
            });
        },
    );
};

1;
