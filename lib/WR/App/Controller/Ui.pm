package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use Time::HiRes qw/gettimeofday tv_interval/;
use Filesys::DiskUsage::Fast qw/du/;
use Mojo::Util qw/url_escape/;
use Mango::BSON;
use Data::Dumper;

sub doc {
    my $self = shift;
    
    $self->respond(template => 'doc/index', stash => {
        page => { title => $self->loc(sprintf('page.%s.title', $self->stash('docfile'))) }
    })
}

sub frontpage {
    my $self    = shift;
    my $start   = [ gettimeofday ];
    my $newest  = [];
    my $replays = [];
    my $filter  = (defined($self->stash('frontpage.filter'))) ? $self->stash('frontpage.filter') : {};

    my $query = $self->wr_query(
        sort    => { 'site.uploaded_at' => -1 },
        perpage => 15,
        filter  => $filter,
        panel   => 1,
        );
    $query->page(1 => sub {
        my ($q, $replays) = (@_);

        my $template = ($self->req->is_xhr) ? 'replay/list' : 'index';
        $self->respond(template => $template, stash => {
            replays         => $replays || [],
            page            => { title => 'index.page.title' },
            timing_query    => tv_interval($start),
            sidebar         => {
                alert        =>  {
                    title   =>  'WG API ISSUES',
                    text    => q|<p>It seems the WG API for the Asia cluster has fallen over, and since wotreplays.org uses that API for the signin process, players from the Asia server currently can't sign in on the site. There's no ETA from WG yet as to when this issue will be resolved.</p><p>A side effect is that the site can't obtain overall ratings for players from the Asia cluster at the moment...</p>|,
                },
            }
        });
    });
}

sub xhr_du {
    my $self = shift;

    $self->render_later;

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
                $n->{$_} = sprintf('%.2f', $doc->{$_});
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
        if($real_file =~ /^(mods|patches)/) {
            $self->render(text => 'OK');
        } else {
            $self->model('replays')->update({ file => $real_file }, { '$inc' => { 'site.downloads' => 1 } } => sub {
                $self->render(text => 'OK');
            });
        }
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

    $self->render_later;

    # logging out just means we want to jack up the session cookie
    my $url = 'http://api.statterbox.com/wot/auth/logout';
    my $form = {
        application_id  => $self->config->{statterbox}->{server},
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
            application_id => $self->config->{statterbox}->{server},
            cluster        => $s,
            nofollow       => 1,
            redirect_uri   => sprintf('%s/openid/return', $self->req->url->base),
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
                $self->debug('tx not ok');
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
    my $my_url = $self->req->url->base;
    my $params = $self->req->params->to_hash;

    $self->redirect_to('/') and return if($self->is_user_authenticated);

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
                    my $account = {
                        _id     => sprintf('%s-%s', lc($self->session('auth_server')), lc($params->{nickname})),
                        clan    => undef,
                        player_name     => $params->{nickname},
                        player_server   => $self->session('auth_server'),
                        access_token    => $params->{access_token},
                        expires_at      => Mango::BSON::bson_time(($params->{expires_at} + 0) * 1000),
                    };
                    $self->debug('updating account with: ', Dumper($account));
                    $self->model('wot-replays.accounts')->save($account => sub {
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

sub _get_lang_data {
    my $self = shift;
    my $what = shift;
    my $data = {};

    if(my $fh = IO::File->new(sprintf('%s/%s/site.po', $self->app->home->rel_dir('lang/site'), $what))) {
        my $id = undef;
        my $val = undef;
        while(my $line = <$fh>) {
            if($line =~ /msgid\s+\"(.*?)\"/) {
                $id = $1;
            } elsif($line =~ /msgstr\s+"(.*)\"/) {
                $data->{$id} = $1;
                $id = undef;
            }
        }
        $fh->close;
    }
    return $data;
}

sub xhr_po {
    my $self = shift;
    my $lang = $self->stash('lang');
    my $common = $self->_get_lang_data('common');
    my $ldata  = $self->_get_lang_data($lang);
    $self->stash(catalog => $self->i18n_catalog);
    $self->render(template => 'xhr/po');
}

1;
