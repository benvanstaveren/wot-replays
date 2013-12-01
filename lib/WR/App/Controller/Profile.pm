package WR::App::Controller::Profile;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use Mango::BSON;

sub check {
    my $self = shift;
    return 1 if($self->is_user_authenticated);
    $self->redirect_to('/login') and return 0;
}

sub hr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub sr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_true }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub replays {
    my $self = shift;
    my $type = $self->stash('type');
    my $page = $self->stash('page');
    my $query = {
        'game.recorder.name' => $self->stash('current_player_name'),
        'game.server' => lc($self->stash('current_player_server')),
        };


    if($type eq 'p') {  
        $query->{'site.visible'} = Mango::BSON::bson_true;
    } elsif($type eq 'h') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
    }

    $self->render_later;

    my $cursor = $self->model('wot-replays.replays')->find($query);
    $cursor->count(sub {
        my ($cursor, $e, $count) = (@_);
        my $maxp   = int($count/10);
        $maxp++ if($maxp * 10 < $count);

        $cursor->skip( ($page - 1) * 10 );
        $cursor->limit(15);
        $cursor->sort({ 'site.uploaded_at' => -1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            my $replays = [ map { WR::Query->fuck_tt($_) } @$docs ];
            $self->respond(template => 'profile/replays', stash => {
                page => {
                    title => 'Your Profile - Replays',
                },
                maxp => $maxp,
                type => $type,
                p    => $page,
                replays => $replays,
                total_replays => $count,
            });
        });
    });
}

1;
