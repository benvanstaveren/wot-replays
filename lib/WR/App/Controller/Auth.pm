package WR::App::Controller::Auth;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use Data::Dumper;

sub do_logout {
    my $self = shift;

    $self->render_later;

    # logging out just means we want to jack up the session cookie
    my $url = 'http://api.statterbox.com/wot/auth/logout';
    my $form = {
        application_id  => $self->get_config('statterbox.server'),
        cluster         => $self->fix_server($self->current_user->{player_server}),
        access_token    => $self->current_user->{access_token},
    };
    $self->ua->inactivity_timeout(30);
    $self->ua->post($url => form => $form => sub {
        my ($ua, $tx) = (@_);
        if(my $res = $tx->success) {
            $self->debug('logout res says: ', Dumper($res->json));
            $self->session('openid' => undef);
            $self->session(notify  => { type => 'notify', text => 'You logged out successfully', sticky => 0, close => 1 });
        } 
        $self->redirect_to('/');
    });
}

sub do_link {
    my $self = shift;
    my $s    = $self->stash('s'); # $self->req->param('s');

    if(defined($s)) {
        $self->render_later;

        $self->session(
            'link_server' => $s,
            'link_nonce'  => Mango::BSON::bson_oid . '',
        );

        my $url = 'http://api.statterbox.com/wot/auth/login';
        my $form = {
            application_id => $self->get_config('statterbox.server'),
            cluster        => $s,
            nofollow       => 1,
            redirect_uri   => sprintf('%s/openid/return/link', $self->req->url->base),
            expires_at     => 86400 * 7,
        };

        $self->ua->inactivity_timeout(30);
        $self->ua->post($url => form => $form => sub {
            my ($ua, $tx) = (@_);
            if(my $res = $tx->success) {
                if($res->json('/status') eq 'ok') {
                    $self->debug('tx ok, status ok');
                    $self->redirect_to($res->json('/data/location'));
                } else {
                    $self->debug('tx ok, status not ok: ', Dumper($res->json));
                    # FIXME FIXME FIXME
                    $self->respond(template => 'profile/link', stash => {
                        page => { title => 'Link Account' },
                        notify => 'Link failed, please try again',
                    });
                }
            } else {
                my ($err, $code) = $tx->error;
                $self->debug('tx not ok: code: ', $code, ' err: ', $err);
                $self->respond(template => 'profile/link', stash => {
                    page => { title => 'Link Account' },
                    notify => 'Link failed, please try again',
                });
            }
        });
    } else {
        $self->respond(template => 'profile/link', stash => {
            page => { title => 'Link Account' },
        });
    }
}

sub do_login {
    my $self = shift;
    my $s    = $self->stash('s'); # $self->req->param('s');

    $self->redirect_to('/') and return if($self->is_user_authenticated);

    if(defined($s)) {
        $self->render_later;

        # fix for the sea -> asia move
        $s = 'asia' if($s eq 'sea');

        $self->session(
            'auth_server' => ($s eq 'asia') ? 'sea' : $s,   # and we fix it right back too... 
            'auth_nonce'  => Mango::BSON::bson_oid . '',
        );

        my $url = 'http://api.statterbox.com/wot/auth/login';
        my $form = {
            application_id => $self->get_config('statterbox.server'),
            cluster        => $s,
            nofollow       => 1,
            redirect_uri   => sprintf('%s/openid/return/default', $self->req->url->base),
            expires_at     => 86400 * 7,
        };

        $self->debug('set session auth_server to ', $self->session('auth_server'), ' and nonce to ', $self->session('auth_nonce'));

        $self->ua->inactivity_timeout(30);
        $self->ua->post($url => form => $form => sub {
            my ($ua, $tx) = (@_);
            if(my $res = $tx->success) {
                if($res->json('/status') eq 'ok') {
                    $self->debug('tx ok, status ok');
                    $self->redirect_to($res->json('/data/location'));
                } else {
                    $self->debug('tx ok, status not ok: ', Dumper($res->json));
                    $self->respond(template => 'login/form', stash => {
                        page => { title => 'Login' },
                        notify => { title => 'error', text => 'An API error occurred ' . ($self->is_the_boss) ? Dumper($res->json('/error')) : '', sticky => 1, close => 1 },
                    });
                }
            } else {
                my ($err, $code) = $tx->error;
                $self->debug('tx not ok: code: ', $code, ' err: ', $err);
                $self->respond(template => 'login/form', stash => {
                    page => { title => 'Login' },
                    notify => { title => 'error', text => 'API timeout, try again' }
                });
            }
        });
    } else {
        $self->respond(template => 'login/form', stash => {
            page => { title => 'Login' },
        });
    }
}

sub openid_return {
    my $self   = shift;
    my $type   = $self->stash('type');

    if($type eq 'default') {
        $self->openid_return_default;
    } elsif($type eq 'link') {
        $self->openid_return_link;
    } else {
        $self->redirect_to('/') and return if($self->is_user_authenticated);
    }
}

sub openid_return_link {
    my $self   = shift;
    my $my_url = $self->req->url->base;
    my $params = $self->req->params->to_hash;

    $self->debug('openid_return_link, params: ', Dumper($params));

    if($params->{status} eq 'ok') {
        if(!defined($self->session('link_nonce')) || !defined($self->session('link_server'))) {
            $self->debug('status ok, but no link_nonce or link_server in session: ', Dumper($self->session));
            $self->respond(template => 'profile/link', stash => {
                page => { title => 'Link Account' },
                notify => 'No link nonce or link server found in session',
            });
        } else {
            $self->render_later;
            $self->model('wot-replays.openid_nonce_cache')->find_one({ _id => $self->session('link_nonce') } => sub {
                my ($coll, $err, $doc) = (@_);

                if(defined($doc)) {
                    $self->debug('dupe nonce');
                    # FIXME FIXME FIXME
                    $self->respond(template => 'profile/link', stash => {
                        page => { title => 'Link Account' },
                        notify => 'Duplicate nonce',
                    });
                } else {
                    my $id = sprintf('%s-%s', lc($self->session('link_server')), lc($params->{nickname}));
                    $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, { '$push' => { 'ucid' => $id } } => sub {
                        $self->redirect_to('/profile/linked/okay');
                    });
                }
            });
        }
    } else {
        $self->respond(template => 'profile/link', stash => {
            page => { title => 'Link Account' },
            notify => 'Login failed or cancelled, please try again',
        });
    }
}

sub openid_return_default {
    my $self   = shift;
    my $my_url = $self->req->url->base;
    my $params = $self->req->params->to_hash;

    $self->debug('openid_return, params: ', Dumper($params));

    if($params->{status} eq 'ok') {
        if(!defined($self->session('auth_nonce')) || !defined($self->session('auth_server'))) {
            $self->debug('status ok, but no auth_nonce or auth_server in session: ', Dumper($self->session));
            $self->respond(template => 'login/form', stash => {
                page    => { title => 'Login' },
                notify  => { type => 'error', text => 'Session lost', sticky => 0, close => 1 },
            });
        } else {
            $self->render_later;
            $self->model('wot-replays.openid_nonce_cache')->find_one({ _id => $self->session('auth_nonce') } => sub {
                my ($coll, $err, $doc) = (@_);

                if(defined($doc)) {
                    $self->debug('dupe nonce');
                    $self->respond(template => 'login/form', stash => {
                        page    => { title => 'Login' },
                        notify  => { type => 'error', text => 'Duplicate nonce', sticky => 0, close => 1 },
                    });
                } else {
                    my $id = sprintf('%s-%s', lc($self->session('auth_server')), lc($params->{nickname})),
                    my $set = {
                        player_name     => $params->{nickname},
                        player_server   => $self->session('auth_server'),
                        access_token    => $params->{access_token},
                        expires_at      => Mango::BSON::bson_time(($params->{expires_at} + 0) * 1000),
                    };
                    $self->model('wot-replays.accounts')->update({ _id => $id }, { '$set' => $set }, { upsert => 1 }  => sub {
                        my ($coll, $err, $oid) = (@_);
                        $self->model('wot-replays.openid_nonce_cache')->save({ _id => $self->session('auth_nonce'), used => Mango::BSON::bson_time, used_by => (defined($err)) ? undef : $oid } => sub {
                            $self->session('openid' => sprintf('%s-%s', lc($self->session('auth_server')), lc($params->{nickname})));
                            $self->session('notify' => { type => 'info', text => 'Login successful', close => 1 }),
                            $self->redirect_to('/');
                        });
                    });
                }
            });
        }
    } else {
        $self->respond(template => 'login/form', stash => {
            page    => { title => 'Login' },
            notify  => { type => 'error', text => 'Wargaming.net signin failed', sticky => 0, close => 1 },
        });
    }
}

1;
