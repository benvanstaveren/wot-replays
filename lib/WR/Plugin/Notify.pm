package WR::Plugin::Notify;
use Mojo::Base 'Mojolicious::Plugin';
use Mango::BSON;
use WR::Provider::DismissableNotification;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->hook(around_action => sub {
        my ($next, $c, $action, $last) = (@_);
        if(my $notify = $c->session->{'notify'}) {
            delete($c->session->{'notify'});
            $c->stash(notify => $notify);
        }
        return $next->();
    });

    $app->hook(before_routes => sub {
        my $c = shift;

        my $utrack = $c->session('utrack');
        if(!defined($utrack)) {
            $utrack = Mango::BSON::bson_oid . '' ;
            $c->session('utrack' => $utrack);
        }
        $c->stash(_dnotification => WR::Provider::DismissableNotification->new(utrack => $utrack, db => $c->get_database));
    });

    $app->helper(notification_list => sub {
        my $self = shift;
        my $cb   = shift; 

        return $self->stash('_dnotification')->list($cb);
    });

    $app->helper(dismiss_notification => sub {
        my $self = shift;
        my $nid  = shift;
        my $cb   = shift; 

        return $self->stash('_dnotification')->dismiss($nid => $cb);
    });
}

1;
