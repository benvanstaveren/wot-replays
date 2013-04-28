package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use boolean;
use Cache::File;
use Net::OpenID::Consumer;
use URI::Escape;
use LWPx::ParanoidAgent;
use Time::HiRes qw/gettimeofday tv_interval/;

sub xd {
    my $self = shift;

    $self->res->headers->header('Access-Control-Allow-Origin' => $self->req->headers->header('Origin'));
    $self->render(text => q|var WR_CORS = true;|, status => 200);
}

sub faq {
    shift->respond(template => 'faq', stash => { page => { title => 'Frequently Asked Questions' } });
}

sub donate {
    shift->respond(template => 'donate', stash => { page => { title => 'Donations Welcome' } });
}

sub about {
    shift->respond(template => 'about', stash => { page => { title => 'About' } });
}

sub credits {
    shift->respond(template => 'credits', stash => { page => { title => 'Credits' } });
}

sub hint {
    my $self = shift;
    my $id   = $self->stash('hintid');
    my $v    = $self->req->param('set');

    $self->session($id => $v);
    $self->render(json => { ok => 1 });
}

sub generate_replay_count {
    my $self = shift;

    # get the different replays and versions using group()
    my $r_stats = $self->db('wot-replays')->get_collection('replays')->group({
        initial => { 
            count => 0,
            },
        key => { 'version' => 1, 'site.visible' => 1 },
        reduce => q|function(obj, prev) { prev.count += 1 }|,
    })->{retval};

    my $stats = {};
    foreach my $item (@$r_stats) {
        $stats->{v}->{$item->{version}}->{total} += $item->{count};
        $stats->{v}->{$item->{version}}->{($item->{'site.visible'}) ? 'visible' : 'hidden'} = $item->{count};
        $stats->{t} += $item->{count};
    }

    delete($stats->{''});
    return $stats || {};
}

sub index {
    my $self    = shift;
    my $start   = [ gettimeofday ];
    my $newest  = [ $self->model(sprintf('wot-replays.newest.%s', $self->stash('req_host')))->find()->sort({ '$natural' => -1 })->all() ];
    my $replays = [];

    foreach my $id (@$newest) {
        push(@$replays, WR::Query->fuck_tt($self->model('wot-replays.replays')->find_one({ _id => $id->{replay} })));
    }

    my $total = $self->model('wot-replays.replays')->count();
    my $archived = $self->model('wot-replays.replays')->find({ 'site.download_disabled' => true })->count();

    if($self->req->is_xhr) {
        $self->respond(template => 'index/ajax', stash => {
            replays         => $replays,
            replay_count    => $total + 0,
            archived_count  => $archived + 0,
            timing_query    => tv_interval($start),
        });
    } else {
        $self->respond(template => 'index', stash => {
            page            => { title => 'Home' },
            replays         => $replays,
            replay_count    => $total + 0,
            archived_count  => $archived + 0,
            timing_query    => tv_interval($start),
        });
    }
}

sub register { shift->respond(template => 'register/form', stash => { page => { title => 'Registration No Longer Required' } }) }

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

    if(defined($s)) {
        my %params = @{ $self->req->params->params };
        my $my_url = $self->req->url->base;
        my $cache = Cache::File->new(cache_root => sprintf('%s/openid', $self->app->home->rel_dir('tmp/cache')));
        my $csr = Net::OpenID::Consumer->new(
            ua              => LWPx::ParanoidAgent->new,
            cache           => $cache,
            args            => \%params,
            consumer_secret => $self->app->secret,
            required_root   => $my_url,
            debug           => 1,
        );
        my $url = sprintf('http://%s.wargaming.net/id/', $s);
        if(my $claimed_identity = $csr->claimed_identity($url)) {
            my $check_url = $claimed_identity->check_url(
                return_to      => qq{$my_url/openid/return},
                trust_root     => qq{$my_url/},
                delayed_return => 1,
            );
            return $self->redirect_to($check_url);
        } else {
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

    my $cache = Cache::File->new(cache_root => sprintf('%s/openid', $self->app->home->rel_dir('tmp/cache')));
    my $csr = Net::OpenID::Consumer->new(
        ua              => LWPx::ParanoidAgent->new,
        cache           => $cache,
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
            my $setup_url = shift;
            $setup_url = URI::Escape::uri_unescape($setup_url);
            return $self->redirect_to($setup_url);
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

            # find an account that has this ID associted with it, if no account exists, 
            # offer people an opportunity via profile to re-claim an existing account

            unless(my $account = $self->model('wot-replays.accounts')->find_one({ openid => $vident->url })) {
                $self->model('wot-replays.accounts')->save({ 
                    openid => $vident->url
                });
            }
            $self->session(
                'openid' => $vident->url,
                'notify' => { type => 'info', text => 'Login successful', close => 1 },
            );
            $self->redirect_to('/');
        },
        error => sub {
            my $err = shift;
            $self->respond(template => 'login/form', stash => {
                page    => { title => 'Login' },
                notify  => { type => 'error', text => sprintf('OpenID Error: %s', $err), sticky => 0, cloes => 1 },
            });
        },
    );
};

1;
