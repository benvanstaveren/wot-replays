package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use boolean;

sub faq {
    shift->respond(template => 'faq', stash => { page => { title => 'Frequently Asked Questions' } });
}

sub donate {
    shift->respond(template => 'donate', stash => { page => { title => 'Donations Welcome' } });
}

sub about {
    shift->respond(template => 'about', stash => { page => { title => 'About' } });
}

sub about {
    shift->respond(template => 'credits', stash => { page => { title => 'Credits' } });
}

sub dlg_achievement {
    my $self = shift;
    my $a    = $self->stash('achievement');
    my $d;
   
    if($a =~ /^markOfMastery/) {
        $d = 'markOfMastery_descr';
    } else {
        $d = sprintf('%s_descr', $a);
    }

    my $res = WR::Res::Achievements->new();
    my $desc = $res->i18n($d);

    $desc =~ s/\\t/<br\/><span style="margin-left: 20px"><\/span>/g;

    $self->stash(
        title => $res->i18n($a),
        desc  => $desc,
    );
    $self->render(template => 'dlg/achievement');
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
        $stats->{$item->{version}}->{total} += $item->{count};
        $stats->{$item->{version}}->{($item->{'site.visible'}) ? 'visible' : 'hidden'} = $item->{count};
    }

    delete($stats->{''});

    return $stats || {};
}

sub index {
    my $self = shift;

    # let's just do this by hand, fuck TT and it's private setting and it not wanting to use it properly.
    # fuck it up the ass with a big black rubber cock.
    my $replays = [ 
        map { { %{$_}, id => $_->{_id} } } $self->db('wot-replays')->get_collection('replays')->find({
            'site.visible' => true,
            # 'version'      => $self->stash('config')->{wot}->{version},   # no longer used since the 0.7.4
                                                                            # WoT client will play old replays
        })->sort({ 'site.uploaded_at' => -1 })->limit(15)->all()
    ];

    #my $rc = $self->cachable(
    #    key => 'frontpage_replay_count',
    #    ttl => 120,
    #    method => 'generate_replay_count',
    #);

    $self->respond(template => 'index', stash => {
        page => { title => 'Home' },
        replays => $replays,
        #replay_count => $rc,
    });
}

sub register {
    my $self = shift;
    my $error;

    if($self->req->param('a')) {
        my $e = $self->req->param('u');
        my $p = $self->req->param('p');
        my $p2 = $self->req->param('p2');

        if($e && $p && $p2) {
            if($p eq undef || $p ne $p2) {
                $error = 'You missed a field...';
            } else {
                if($e !~ /^.*\@.*\.\w{2,3}$/) {
                    $error = 'That does not look like an email address to me';
                } else {
                    if($self->db('wot-replays')->get_collection('accounts')->find_one({ email => $e })) {
                        $error = 'Oops, email already in use!';
                    } else {
                        my $data = {
                            email => $e,
                            password => crypt($p, 'wr'),
                            };
                        $self->db('wot-replays')->get_collection('accounts')->save($data);
                        $error = undef;
                    }
                }
            }
        } else {
            $error = 'You missed a field...';
        }
        $self->respond(template => 'register/form', stash => {
            page => { title => 'Register Account' },
            ($error) ? ( errormessage => $error ) : ( done => 1 )
        });
    } else {
        $self->respond(template => 'register/form', stash => { page => { title => 'Register Account' } });
    }
}

sub do_logout {
    my $self = shift;

    $self->logout();
    $self->redirect_to('/');
}

sub login {
    my $self = shift;
    my $a = $self->req->param('a');
    my $error;

    if(defined($a) && $a eq 'login') {
        my $e = $self->req->param('email');
        my $p = $self->req->param('password');
        if($e && $p) {
            if($self->authenticate($e, $p)) {
                $self->respond(template => 'login/form', stash => {
                    page => { title => 'Login' },
                    done => 1,
                });
            } else {
                $self->respond(template => 'login/form', stash => {
                    page => { title => 'Login' },
                    errormessage => 'Invalid credentials',
                });
            }
        } else {
            $self->respond(template => 'login/form', stash => {
                page => { title => 'Login' },
                errormessage => 'You do know both fields are required, right?',
            });
        }
    } else {
        $self->respond(template => 'login/form', stash => {
            page => { title => 'Login' },
        });
    }
}

1;
