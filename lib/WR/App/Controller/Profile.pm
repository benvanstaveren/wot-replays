package WR::App::Controller::Profile;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use boolean;
use WR::PlayerProfileData;

sub check {
    my $self = shift;

    return 1 if($self->is_user_authenticated);
    $self->redirect_to('/login') and return 0;
}

sub sr {
    my $self = shift;
    my $id = bless({ value => $self->req->param('id') }, 'MongoDB::OID');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id, 'site.uploaded_by' => $self->current_user->{_id} })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$set' => { 'site.visible' => true } });
        $self->render(json => { ok => 1 });
    } else {
        $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
    }
}

sub hr {
    my $self = shift;
    my $id = bless({ value => $self->req->param('id') }, 'MongoDB::OID');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id, 'site.uploaded_by' => $self->current_user->{_id} })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$set' => { 'site.visible' => false } });
        $self->render(json => { ok => 1 });
    } else {
        $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
    }
}

sub index {
    my $self = shift;

    $self->respond(
        template => 'profile/index',
        stash => {
            profile_replay_type => $self->session('profile_replay_type'),
            page => { title => 'Your Profile' },
        },
    );
}

sub reclaim {
    my $self = shift;
    my $a    = $self->req->param('a');
    my $error;
      
    if(defined($a) && $a eq 'login') {
        my $e = $self->req->param('email');
        my $p = $self->req->param('password');
        if($e && $p) {
            if(my $user = $self->model('wot-replays.accounts')->find_one({ email => $e })) {
                my $salt = substr($user->{password}, 0, 2);
                my $npass = crypt($p, $salt);

                if($user->{password} eq $npass) {
                    $self->model('wot-replays.accounts')->remove({ openid => $self->session('openid') });
                    $self->model('wot-replays.accounts')->update({ _id => $user->{_id} }, {
                        '$set' => {
                            openid => $self->session('openid'),
                            reclaimed => true,
                        }
                    });
                    $self->session('notify' => { type => 'info', text => 'Account reclaimed successfully!', close => 1 });
                    $self->redirect_to('/profile');
                } else {
                    $self->respond(template => 'profile/reclaim', stash => {
                        page => { title => 'Reclaim Account' },
                        notify => { type => 'error', text => 'Invalid credentials', sticky => 1 },
                    });
                }
            } else {
                $self->respond(template => 'profile/reclaim', stash => {
                    page => { title => 'Reclaim Account' },
                    notify => { type => 'error', text => 'No such user', sticky => 1 },
                });
            }
        } else {
            $self->respond(template => 'profile/reclaim', stash => {
                page => { title => 'Login' },
                notify => { type => 'error', text => 'You do know both fields are required, right?', sticky => 1 },
            });
        }
    } else {
       $self->respond(template => 'profile/reclaim', stash => { page => { title => 'Reclaim Account' } });
    }
}

sub replays {
    my $self = shift;
    my $type = $self->req->param('type');
    my $query = {
        'site.uploaded_by' => $self->current_user->{_id},
        };
    my $coll = $self->db('wot-replays')->get_collection('replays');
    my $p = $self->req->param('p') || 1;

    $self->session('profile_replay_type' => $type);

    if($type eq 'p') {  
        $query->{'site.visible'} = true;
    } elsif($type eq 'h') {
        $query->{'site.visible'} = false;
    }

    my $cursor = $coll->find($query);
    my $count = $cursor->count();
    my $maxp = int($count/25);
    $maxp++ if($maxp * 25 < $count);

    $cursor->skip( ($p - 1) * 25 );
    $cursor->limit(25);
    $cursor->sort({ 'site.uploaded_at' => -1 });
    
    $self->respond(template => 'profile/replays', stash => {
        maxp => $maxp,
        type => $type,
        p    => $p,
        replays => [ map { { %$_, id => $_->{_id} } } $cursor->all() ],
        total_replays => $count,
    });
}

sub settings {
    my $self = shift;

    $self->respond(
        template => 'profile/settings',
        stash => {
            page => { title => 'Your Profile - Settings' },
        },
    );
}

sub overview {
}

1;
