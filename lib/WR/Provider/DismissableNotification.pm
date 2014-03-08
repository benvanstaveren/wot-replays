package WR::Provider::DismissableNotification;
use Mojo::Base '-base';

# user track ID, stored in session under 'utrack', when not supplied is generated automatically

has 'utrack'    =>  undef; 
has 'db'        =>  undef; 

sub model {
    my $self = shift;
    my $n    = shift;

    return $self->db->collection($n);
}

sub dismiss {
    my $self = shift;
    my $nid  = shift;
    my $cb   = shift;

    $self->model('dn_track')->insert({ utrack => $self->utrack, notification => $nid } => $cb);
}

sub list {
    my $self = shift;
    my $cb   = shift;

    # grab a list of dismissed notifications first
    $self->model('dn_track')->find({ utrack => $self->utrack })->all(sub {
        my ($c, $e, $d) = (@_);
        my $seen_list = [ map { $_->{notification} } @$d ];

        my $notifications = [];

        $self->model('notifications')->find({ _id => { '$nin' => $seen_list } })->sort({ _ctime => -1 })->all(sub {
            my ($c, $e, $d) = (@_);

            foreach my $n (@$d) {
                push(@$notifications, {
                    id      => $n->{_id},
                    title   => $n->{title},
                    text    => $n->{text},
                    type    => $n->{type},
                });
            }
            return $cb->($notifications);
        });
    });
}

1;
