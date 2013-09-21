package GEQ::Subscribe;
use Mojo::Base '-base';
use Mango::BSON;
use Data::Dumper;

has 'db'        => undef;
has 'last_time' => sub { Mango::BSON::bson_time };
has 'cname'     => 'ghetto_event_queue';
has 'scopes'    => sub { { '*' => 1 } };

sub watch {
    my $self = shift;
    my $scope = shift;

    $self->scopes->{$scope}++;
}

sub ignore {
    my $self = shift;
    my $scope = shift;

    delete($self->scopes->{$scope});
}

sub watch_only {
    my $self = shift;
    my $scope = shift;

    $self->scopes({ $scope => 1 });
}

sub next {
    my $self = shift;
    my $cb   = shift;

    my $s = [ keys(%{$self->scopes}) ];
    my $q = { scope => { '$in' => $s }, time => { '$gt' => $self->last_time } };

    my $cursor = $self->db->collection($self->cname)->find($q);
    $cursor->sort({ time =>  1 });

    if($cb) {
        $cursor->next(sub {
            my ($c, $e, $d) = (@_);
            if(!$e) {
                if($d) {
                    $self->last_time($d->{time});
                    $cb->($d);
                } else {
                    $cb->(undef);
                }
            } else {
                $cb->(undef);
            }
        });
    } else {
        if(my $event = $cursor->next()) {
            $self->last_time($event->{time});
            return $event;
        } else {
            return undef;
        }
    }
}

sub all {
    my $self = shift;
    my $cb   = shift;

    my $s = [ keys(%{$self->scopes}) ];
    my $q = { scope => { '$in' => $s }, time => { '$gt' => $self->last_time } };

    warn Dumper($q);

    my $cursor = $self->db->collection($self->cname)->find($q);
    $cursor->sort({ time =>  1 });

    if($cb) {
        $cursor->all(sub {
            my ($c, $e, $d) = (@_);

            my $hightime = 0;
            my $events = [];

            if(!$e) {
                if($d) {
                    foreach my $rawe (@$d) {
                        $hightime = $rawe->{time} if($rawe->{time} > $hightime);
                        push(@$events, $rawe->{event});
                    }
                    $self->last_time($hightime);
                    $cb->({ time => $hightime, events => $events});
                } else {
                    $cb->(undef);
                }
            } else {
                $cb->(undef);
            }
        });
    } else {
        my $res = $cursor->all;
        my $hightime = 0;
        my $events = [];
        foreach my $rawe (@$res) {
            $hightime = $rawe->{time} if($rawe->{time} > $hightime);
            push(@$events, $rawe->{event});
        }
        $self->last_time($hightime);
        return { time => $hightime, events => $events };
    }
}

1;
