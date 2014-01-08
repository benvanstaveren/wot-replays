package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use boolean;
use Time::HiRes qw/gettimeofday tv_interval/;
use Filesys::DiskUsage::Fast qw/du/;
use WR::OpenID;
use Mango::BSON;

sub auto {
    my $self = shift;

    $self->auth_setup(sub {
        my $c = shift;
        my $user = shift;

        if(defined($user)) {
            $c->stash(current_user => $user);
            $c->stash(current_player_name => $user->{player_name});
            $c->stash(current_player_server => uc($user->{player_server}));

            $c->current_user->{last_clan_check} ||= 0;

            if($c->current_user->{last_clan_check} < Mango::BSON::bson_time( (time() - 86400) * 1000)) {
                # we need to re-check the users' clan settings, we do that by yoinking statterbox for it
                 my $url = sprintf('http://statterbox.com/api/v1/%s/clan?server=%s&player=%s', 
                        '5299a074907e1337e0010000', # yes it's a hardcoded API token :P
                        lc($c->current_user->{player_server}),
                        lc($c->current_user->{player_name}),
                        );
                $c->ua->get($url => sub {
                    my ($ua, $tx) = (@_);
                    my $clan = undef;
                    
                    if(my $res = $tx->success) {
                        if($res->json->{ok} == 1) {
                            $clan = $res->json->{data}->{lc($c->current_user->{player_name})};
                        } else {
                            $clan = undef;
                        }
                    } else {
                        $clan = undef;
                    }
                    $c->current_user->{clan} = $clan;
                    $c->update_current_user({
                        'last_clan_check' => Mango::BSON::bson_time,
                        'clan'            => $clan,
                    } => sub {
                        $c->continue;
                    });
                });
            } else {
                $c->continue;
            }
        } else {
            if(defined($c->stash('mustauth')) && ($c->stash('mustauth') == 1)) {
                # we do want to call the setup end but with a redirect
                $c->redirect_to('/login');
            } else {
                $c->continue;
            }
        }
    });
    return undef;
}

sub doc {
    my $self = shift;
    
    $self->respond(template => 'doc/index', stash => {
        page => { title => $self->loc(sprintf('page.%s.title', $self->stash('docfile'))) }
    })
}

sub index {
    my $self    = shift;
    my $start   = [ gettimeofday ];
    my $newest  = [];
    my $replays = [];

    # here we generate a bunch of hoohah 
    $self->render_later;

    # no need for a count
    my $cursor = $self->model('replays')->find({ 'site.visible' => Mango::BSON::bson_true })->sort({ 'site.uploaded_at' => -1 })->limit(15)->fields({ panel => 1, site => 1, file => 1 })->all(sub {
        my ($c, $e, $replays) = (@_);
        $self->respond(template => 'index', stash => {
            replays         => $replays || [],
            page            => { title => $self->loc('index.page.title') },
            timing_query    => tv_interval($start),
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

    # logging out just means we want to jack up the session cookie
    $self->session('openid' => undef);

    $self->respond(template => 'login/form', stash => {
        page => { title => 'Login' },
        notify  => { type => 'notify', text => 'You logged out successfully', sticky => 0, close => 1 },
    });
}

sub do_login {
    my $self = shift;
    my $s    = $self->stash('s'); # $self->req->param('s');

    if(defined($s)) {
        # fix for the sea -> asia move
        $s = 'asia' if($s eq 'sea');

        my $url = sprintf('http://%s.wargaming.net/', $s);
        my $my_url = $self->req->url->base;
        my $o = WR::OpenID->new(realm => $my_url, region => $s, schema => 'https', ua => $self->ua, return_to => sprintf('%s/openid/return', $my_url));
        $self->redirect_to($o->checkid_setup($url));
    } else {
        $self->respond(template => 'login/form', stash => {
            page => { title => 'Login' },
        });
    }
}

sub openid_return {
    my $self   = shift;
    my $my_url = $self->req->url->base;
    my $params = { @{$self->req->params} };

    my $o = WR::OpenID->new(realm => $my_url, ua => $self->ua, return_to => sprintf('%s/openid/return', $my_url), nonce_cache => $self->model('wot-replays.openid_nonce_cache'));

    $o->on('not_openid' => sub {
        $self->respond(template => 'login/form', stash => {
            page    => { title => 'Login' },
            notify  => { type => 'error', text => 'A message was received that was not an OpenID message', sticky => 1, close => 1 },
        });
    });

    $o->on('setup_needed' => sub {
        $self->redirect_to($params->{'openid.user_setup_url'});
    });

    $o->on('cancelled' => sub {
        $self->respond(template => 'login/form', stash => {
            page    => { title => 'Login' },
            notify  => { type => 'error', text => 'You cancelled the signin process', sticky => 0, close => 1 },
        });
    });

    $o->on('verified' => sub {
        my $o  = shift;
        my $ident = shift;

        $self->session('openid' => $ident, 'notify' => { type => 'info', text => 'Login successful', close => 1 }),
        $self->redirect_to('/');
    });

    $o->on('error' => sub {
        my $o = shift;
        my $err = shift;

        $self->respond(template => 'login/form', stash => {
            page    => { title => 'Login' },
            notify  => { type => 'error', text => sprintf('OpenID Error: %s', $err), sticky => 0, close => 1 },
        });
    });

    $o->response(params => $params);
};

1;
