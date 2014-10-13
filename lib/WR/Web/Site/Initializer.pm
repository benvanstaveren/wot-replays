package WR::Web::Site::Initializer;
use strict;
use warnings;

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
