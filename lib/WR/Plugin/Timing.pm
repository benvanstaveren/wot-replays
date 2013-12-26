package WR::Plugin::Timing;
use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes qw/gettimeofday tv_interval/;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->hook(around_action => sub {
        my ($next, $c, $action, $last) = (@_);

        my $start = [ gettimeofday ];
        $c->stash('timing.start' => $start);
        my $rv = $next->();
        $c->stash('timing_elapsed' => tv_interval($start));
        return $rv;
    });
}

1;
