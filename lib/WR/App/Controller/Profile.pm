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

sub settings {
    my $self = shift;

    $self->respond(template => 'profile/settings', stash => {
        page => { title => $self->loc('profile.settings.page.title') }
    });
}

sub sl {
    my $self = shift;
    my $l = $self->stash('lang');

    $self->set_language($l);
    $self->settings;
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
        $cursor->limit(10);
        $cursor->sort({ 'site.uploaded_at' => -1 });
        $cursor->fields({ panel => 1, site => 1, file => 1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'profile/replays', stash => {
                page => {
                    title => $self->loc('profile.replays.page.title'),
                },
                maxp => $maxp,
                type => $type,
                p    => $page,
                replays => $docs,
                total_replays => $count,
            });
        });
    });
}

sub uploads {
    my $self = shift;
    my $type = $self->stash('type');
    my $page = $self->stash('page');
    my $query = {
        'uploader.player_name'      => $self->stash('current_player_name'),
        'uploader.player_server'    => lc($self->stash('current_player_server')),
    };

    $self->render_later;

    my $cursor = $self->model('wot-replays.jobs')->find($query);
    $cursor->count(sub {
        my ($cursor, $e, $count) = (@_);
        my $maxp   = int($count/10);
        $maxp++ if($maxp * 10 < $count);

        $cursor->skip( ($page - 1) * 10 );
        $cursor->limit(10);
        $cursor->sort({ 'ctime' => -1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'profile/uploads', stash => {
                page => {
                    title => $self->loc('profile.uploads.page.title'),
                },
                maxp => $maxp,
                type => $type,
                p    => $page,
                uploads => $docs,
            });
        });
    });
}

1;
