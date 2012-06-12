package WR::Controller::Replays::Comment;
use Mojo::Base 'WR::Controller';
use boolean;

sub index {
    my $self = shift;

    my $c = $self->stash('req_replay')->{site}->{comments} || [];

    $self->respond(template => 'replay/view/comments', stash => { comments => $c });
}

sub add {
    my $self = shift;
    my $text = $self->req->param('comment');
    my $dname = $self->req->param('dname');

    $self->render(json => { ok => 0, error => 'Authentication required' }) and return 0 unless($self->is_user_authenticated());

    if(!$self->current_user->{display_name} && !$dname) {
        $self->render(json => { ok => 0, error => 'You need to enter a display name' });
    } elsif(!$self->current_user->{display_name}) {
        if($self->db('wot-replays')->get_collection('accounts')->find_one({'site.display_name' => $dname})) {
            $self->render(json => { ok => 0, error => 'Name taken already, try another one' }) and return 0;
        }
        $self->db('wot-replays')->get_collection('accounts')->update({ 
            _id => $self->current_user->{_id},
        }, { '$set' => { 'display_name' => $dname } });
    }

    my $comment = {
        by => $self->current_user->{_id},
        author => $self->current_user->{display_name} || $dname,
        body => $text,
        date => DateTime->now(),
    };

    $self->db('wot-replays')->get_collection('replays')->update({ 
        _id => $self->stash('req_replay')->{_id},
    }, { 
        '$push' => { 'site.comments' => $comment }
    });

    $self->render(json => { ok => 1 });
}

1;
