package WR::Plugin::Notify;
use Mojo::Base 'Mojolicious::Plugin';

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
}

1;
