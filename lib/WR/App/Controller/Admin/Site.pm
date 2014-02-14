package WR::App::Controller::Admin::Site;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;

sub replays {
    my $self = shift;
    my $page = $self->stash('page');
    my $query = {};

    $self->render_later;

    my $cursor = $self->model('wot-replays.replays')->find($query);
    $cursor->count(sub {
        my ($cursor, $e, $count) = (@_);
        my $maxp   = int($count/50);
        $maxp++ if($maxp * 50 < $count);

        $cursor->skip( ($page - 1) * 50 );
        $cursor->limit(50);
        $cursor->sort({ 'site.uploaded_at' => -1 });
        $cursor->fields({ panel => 1, site => 1, file => 1, game => 1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'admin/site/replays', stash => {
                page => { title => 'Site - Replays' },
                maxp => $maxp,
                p    => $page,
                replays => $docs,
                total_replays => $count,
            });
        });
    });
}

sub uploads {
    my $self = shift;
    my $page = $self->stash('page');

    $self->render_later;

    my $cursor = $self->model('wot-replays.jobs')->find();
    $cursor->count(sub {
        my ($cursor, $e, $count) = (@_);
        my $maxp   = int($count/50);
        $maxp++ if($maxp * 50 < $count);

        $cursor->skip( ($page - 1) * 50 );
        $cursor->limit(50);
        $cursor->sort({ 'ctime' => -1 }); #, 'priority' => -1 });
        #$cursor->fields({ ctime => 1, error => 1, file => 1, data => 1, uploader => 1, status => 1, replayid => 1 });

        $cursor->all(sub {
            my ($c, $e, $docs) = (@_);

            $self->respond(template => 'admin/site/uploads', stash => {
                page => { title => 'Site - Uploads' },
                maxp => $maxp,
                p    => $page,
                uploads => $docs,
                total_uploads => $count,
            });
        });
    });
}

1;
