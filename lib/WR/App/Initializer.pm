package WR::App::Initializer;
use strict;
use warnings;

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

1;
