package WR::Web::Site::Controller::Competition;
use Mojo::Base 'WR::Web::Site::Controller';
use DateTime;
use WR::Event;
use Data::Dumper;

sub bridge {
    my $self = shift;
    my $cid  = $self->stash('competition_id');

    $self->model('wot-replays.competitions')->find_one({ _id => $cid } => sub {
        my ($c, $e, $d) = (@_);

        if(!defined($d) || defined($e)) {
            $self->render(template => 'competition/notfound');
        } else {
            $self->stash(competition => $d, competition_title => $d->{title}, pageid => 'competition', competition_name => $d->{title});
            $self->continue;
        }
    }); 
    return undef;
}

sub view {
    my $self = shift;

    if($self->comp_started) {
        $self->render_later;

        my $config = $self->stash('competition')->{config};

        #$self->debug('view args: ', Dumper($config));
        my $event = WR::Event->new(log => $self->app->log, db => $self->get_database, %$config);
        $event->process(1 => sub {
            my ($event, $top, $other) = (@_);

            $self->stash(toplist => $top, otherlist => $other);
            $self->render(template => 'competition/view');
        });
    } else {
        $self->render(template => 'competition/view');
    }
}

sub list {
    my $self = shift;

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
                } elsif($doc->{config}->{start_time} > $now) {
                    push(@$future, $doc);
                } else {
                    push(@$past, $doc);
                }
            }
            $self->stash(
                future => $future,
                current => $current,
                past => $past,
            );
            $self->render(template => 'competition/list');
        }
    });
}

1;
