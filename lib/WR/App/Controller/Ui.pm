package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
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

sub index {
    my $self = shift;
    my $query = $self->wr_query(
        sort => { 'site.uploaded_at' => -1 },
        perpage => 15,
        filter => {},
        );


    $self->respond(template => 'index', stash => {
        page => { title => 'Home' },
        replays => $query->page(1),
        replay_count => $query->total
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
