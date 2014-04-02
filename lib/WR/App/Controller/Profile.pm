package WR::App::Controller::Profile;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use Mango::BSON;
use DateTime::TimeZone;

sub bridge {
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
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false, 'site.privacy' => 1 }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub cr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false, 'site.privacy' => 3 }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub pr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false, 'site.privacy' => 2 }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub plr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false, 'site.privacy' => 4 }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub tr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_false, 'site.privacy' => 5 }} => sub {
                my ($c, $e, $d) = (@_);
                $self->render(json => { ok => 1 });
            });
        } else {
            $self->render(json => { ok => 0, error => 'Replay does not exist, or it is not yours' });
        }
    });
}

sub setting {
    my $self = shift;
    my $s    = $self->req->param('setting');
    my $v    = $self->req->param('value');

    $self->render_later;
    $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, {
        '$set' => { sprintf('settings.%s', $s) => $v }
    } => sub {
        $self->render(json => { ok => 1 });
    });
}

sub sr {
    my $self = shift;
    my $id = Mango::BSON::bson_oid($self->req->param('id'));

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => $id, 'game.recorder.name' => $self->current_user->{player_name}, 'game.server' => $self->current_user->{player_server} } => sub {
        my ($c, $e, $d) = (@_);

        if($d) {
            $self->model('wot-replays.replays')->update({ _id => $id }, { '$set' => { 'site.visible' => Mango::BSON::bson_true, 'site.privacy' => 0 }} => sub {
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
    my $redir_on_load = shift || 0;
    my $zones = DateTime::TimeZone->all_names;

    $self->respond(template => 'profile/settings', stash => {
        page => { title => 'profile.settings.page.title' },
        timezones => $zones,
    });
}

sub sl {
    my $self = shift;
    my $l = $self->stash('lang');

    $self->set_language($l);
    $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, {
        '$set' => { 'settings.language' => $l },
    } => sub {
        $self->redirect_to('/profile/settings');
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
    } elsif($type eq 'u') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
        $query->{'site.privacy'} = 1;
    } elsif($type eq 'pr') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
        $query->{'site.privacy'} = 2;
    } elsif($type eq 'c') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
        $query->{'site.privacy'} = 3;
    } elsif($type eq 'pl') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
        $query->{'site.privacy'} = 4;
    } elsif($type eq 't') {
        $query->{'site.visible'} = Mango::BSON::bson_false;
        $query->{'site.privacy'} = 5;
    }

    $self->render_later;

    my $cursor = $self->model('wot-replays.replays')->find($query);
    $cursor->count(sub {
        my ($cursor, $e, $count) = (@_);
        my $maxp   = int($count/15);
        $maxp++ if($maxp * 15 < $count);

        $cursor->skip( ($page - 1) * 15 );
        $cursor->limit(15);
        $cursor->sort({ 'site.uploaded_at' => -1 });
        $cursor->fields({ panel => 1, site => 1, file => 1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'profile/replays', stash => {
                maxp => $maxp,
                type => $type,
                p    => $page,
                replays => $docs,
                total_replays => $count,
                page => { title => 'profile.replays.page.title' },
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
        my $maxp   = int($count/15);
        $maxp++ if($maxp * 15 < $count);

        $cursor->skip( ($page - 1) * 15 );
        $cursor->limit(15);
        $cursor->sort({ 'ctime' => -1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'profile/uploads', stash => {
                maxp => $maxp,
                type => $type,
                p    => $page,
                uploads => $docs,
                page => { title => 'profile.uploads.page.title' },
            });
        });
    });
}

1;
