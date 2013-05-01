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

sub setting {
    my $self = shift;
    my $s    = $self->req->param('s');
    my $v    = $self->req->param('v');

    $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, {
        '$set' => {
            sprintf('settings.%s', $s) => ($v) ? 1 : 0,
        },
    });
    $self->render(json => { ok => 1 });
}

sub sr {
    my $self = shift;
    my $id = bless({ value => $self->req->param('id') }, 'MongoDB::OID');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id, 'player.name' => $self->current_user->{player_name}, 'player.server' => $self->current_user->{player_server} })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$set' => { 'site.visible' => true } });
        $self->clear_replay_page($self->req->param('id'));
        $self->render(json => { ok => 1 });
    } else {
        $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
    }
}

sub hr {
    my $self = shift;
    my $id = bless({ value => $self->req->param('id') }, 'MongoDB::OID');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id, 'player.name' => $self->current_user->{player_name}, 'player.server' => $self->current_user->{player_server} })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$set' => { 'site.visible' => false } });
        $self->clear_replay_page($self->req->param('id'));
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
        'player' => $self->stash('current_player_name'),
        'server' => lc($self->stash('current_player_server')),
        };


    my $p = $self->req->param('p') || 1;

    $self->session('profile_replay_type' => $type);

    if($type eq 'p') {  
        $query->{'site.visible'} = true;
    } elsif($type eq 'h') {
        $query->{'site.visible'} = false;
    }

    my $cursor = $self->model('wot-replays.replays.players')->find($query);
    my $count  = $cursor->count();
    my $maxp   = int($count/25);
    $maxp++ if($maxp * 25 < $count);

    $cursor->skip( ($p - 1) * 25 );
    $cursor->limit(25);
    $cursor->sort({ 'uploaded_at' => -1 });
    $cursor->fields({ '_id' => 1, version => 1 });

    my $replays = [];
    foreach my $r ($cursor->all) {
        push(@$replays, 
            WR::Query->fuck_tt(
                $self->model(
                    ($r->{version} eq $self->stash('config')->{wot}->{version}) 
                        ? 'replays' 
                        : sprintf('replays.%s', $r->{version})
                )->find_one({ _id => $r->{_id} })
            )
        );
    }
    
    $self->respond(template => 'profile/replays', stash => {
        maxp => $maxp,
        type => $type,
        p    => $p,
        replays => $replays,
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
