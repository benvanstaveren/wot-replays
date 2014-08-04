package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use Time::HiRes qw/gettimeofday tv_interval/;
use Filesys::DiskUsage::Fast qw/du/;
use Mojo::Util qw/url_escape/;
use Mango::BSON;
use Data::Dumper;

sub doc {
    my $self = shift;

    $self->respond(template => 'doc/index', stash => {
        page => { title => $self->loc(sprintf('page.%s.title', $self->stash('docfile'))) }
    })
}

sub _fp_competitions {
    my $self = shift;
    my $end  = shift;

    $self->model('wot-replays.competitions')->find()->sort({ start_time => 1 })->all(sub {
        my ($c, $e, $d) = (@_);
        
        if(defined($e) || !defined($d)) {
            $self->render(template => 'competition/list');
        } else {
            my $past = [];
            my $current = [];
            my $future = [];
            
            my $now = Mango::BSON::bson_time( DateTime->now(time_zone => 'UTC')->epoch * 1000 );

            foreach my $doc (@$d) {
                if($doc->{config}->{end_time} > $now && $doc->{config}->{start_time} < $now) {
                    push(@$current, $doc);
                }
            }
            $self->stash(competitions => $current);
        }
        $end->();
    });
}

sub _fp_notifications {
    my $self = shift;
    my $end  = shift;

    $self->notification_list(sub {
        my $n = shift;
        $self->stash(notifications => $n);
        $end->();
    });
}

sub frontpage {
    my $self    = shift;

    my $delay   = Mojo::IOLoop->delay(sub {
        $self->continue;
    });
    $self->_fp_competitions($delay->begin(0));
    $self->_fp_notifications($delay->begin(0));
    return undef;
}

sub xhr_du {
    my $self = shift;

    $self->render_later;

    my $bytes = du($self->stash('config')->{paths}->{replays});
    
    $self->render(
        json => {
            bytes => $bytes,
            megabytes => sprintf('%.2f', $bytes / (1024 * 1024)),
            gigabytes => sprintf('%.2f', $bytes / (1024 * 1024 * 1024)),
        }
    );
}

sub xhr_ds {
    my $self = shift;

    $self->render_later;
    $self->get_database->command(Mango::BSON::bson_doc('dbStats' => 1, 'scale' => (1024 * 1024)) => sub {
        my ($db, $err, $doc) = (@_);

        if(defined($doc)) {
            my $n = {};
            for(qw/dataSize storageSize indexSize/) {
                $n->{$_} = sprintf('%.2f', $doc->{$_});
            }
            $self->render(json => { ok => 1, data => $n });
        } else {
            $self->render(json => { ok => 0 });
        }
    });
}

sub nginx_post_action {
    my $self = shift;
    my $file = $self->req->param('f');
    my $stat = $self->req->param('s');

    $self->render_later;
    if(defined($stat) && lc($stat) eq 'ok') {
        my $real_file = substr($file, 1); # because we want to ditch that leading slash
        if($real_file =~ /^(mods|patches)/) {
            $self->render(text => 'OK');
        } else {
            $self->model('replays')->find_and_modify({ 
                query   =>  { file => $real_file },
                update  =>  { '$inc' => { 'site.downloads' => 1 } },
            } => sub {
                my ($c, $e, $d) = (@_);

                if(defined($d)) {
                    $self->_piwik_track_download($file => sub {
                        $self->app->thunderpush->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.download', data => { id => $d->{_id} . '' } }) => sub {
                            my ($p, $r) = (@_);
                            $self->render(text => 'OK');
                        });
                    });
                } else {
                    $self->render(text => 'OK');
                }
            });
        }
    } else {
        $self->render(text => 'OK');
    }
}

sub _piwik_track_download {
    my $self = shift;
    my $file = shift;
    my $cb   = shift;

    $self->ua->get($self->get_config('piwik.url') => form => {
        idsite          => 1,
        token_auth      => $self->get_config('piwik.token_auth'),
        rec             => 1,
        url             => sprintf('http://www.wotreplays.org/download/%s', $file),
        action_name     => 'Replay/Download',
        apiv            => 1,
        download        => sprintf('http://www.wotreplays.org/download/%s', $file),
    } => $cb);
}

sub xhr_qs {
    my $self = shift;

    $self->render_later;
    $self->model('jobs')->find({ ready => Mango::BSON::bson_true, complete => Mango::BSON::bson_false })->count(sub {
        my ($c, $e, $d) = (@_);

        if(defined($d)) {
            $self->render(json => { ok => 1, count => $d });
        } else {
            $self-render(json => { ok => 0 });
        }
    });
}

sub xhr_po {
    my $self = shift;

    $self->stash(lang_catalog => $self->get_catalog_for_js);
    $self->render(template => 'xhr/po');
}

1;
