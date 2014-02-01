package WR::App::Controller::Admin;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use DateTime;

sub bridge {
    my $self = shift;
    return 1 if($self->has_admin_access);
    $self->redirect_to('/') and return 0;
}

sub get_replay_count {
    my $self = shift;
    my $end  = shift;

    $self->model('wot-replays.replays')->find()->count(sub {
        my ($cursor, $err, $count) = (@_);

        $end->({ key => 'total', value => $count });
    });
}

sub get_today_count {
    my $self = shift;
    my $end  = shift;
    my $now  = (DateTime->now(time_zone => 'UTC')->truncate(to => 'day')->epoch * 1000);

    $self->model('wot-replays.replays')->find({ 'site.uploaded_at' => { '$gte' => Mango::BSON::bson_time($now) } })->count(sub {
        my ($cursor, $err, $count) = (@_);

        $end->({ key => 'today', value => $count });
    });
}

sub get_upload_queue {
    my $self = shift;
    my $end  = shift;

    $self->model('wot-replays.jobs')->find({ complete => Mango::BSON::bson_false, ready => Mango::BSON::bson_true })->sort({ ctime => 1, priority => 1 })->all(sub {
        my ($c, $err, $docs) = (@_);

        $end->({ key => 'uploads', value => $docs });
    });
}

sub index {
    my $self = shift;

    $self->render_later;

    my $delay = Mojo::IOLoop->delay(sub {
        my ($delay, @results) = (@_);

        foreach my $r (@results) {
            $self->stash($r->{key} => $r->{value});
        }

        $self->respond(template => 'admin/index', stash => {
            page => { title => 'Dashboard' },
            server_time => DateTime->now(time_zone => 'UTC')->strftime('%d/%m/%Y %H:%M:%S UTC'),
        });
    });

    $self->get_replay_count($delay->begin(0));
    $self->get_today_count($delay->begin(0));
    $self->get_upload_queue($delay->begin(0));
}

1;
