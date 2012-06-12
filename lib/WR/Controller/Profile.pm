package WR::Controller::Profile;
use Mojo::Base 'WR::Controller';
use WR::Query;
use boolean;
use WR::MR;

sub check {
    my $self = shift;

    return 1 if($self->is_user_authenticated);
    $self->redirect_to('/login') and return 0;
}

sub sr {
    my $self = shift;
    my $id = $self->req->param('id');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id, 'site.uploaded_by' => $self->current_user->{_id} })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$set' => { 'site.visible' => true } });
        $self->render(json => { ok => 1 });
    } else {
        $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
    }
}

sub hr {
    my $self = shift;
    my $id = $self->req->param('id');

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

sub settings_auto {
    my $self = shift;
    $self->respond(
        template => 'profile/auto',
        stash => {
            page => { title => 'Your Profile - Settings - Auto Uploader' },
        },
    );
}

1;
