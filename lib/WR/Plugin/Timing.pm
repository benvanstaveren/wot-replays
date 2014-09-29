package WR::Plugin::Timing;
use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes qw/gettimeofday tv_interval/;

sub register {
    my $self = shift;
    my $app  = shift;


    $app->hook(before_dispatch => sub {
        my $c = shift;
        $c->stash('timing.start' => [ gettimeofday ]);
    });

    $app->hook(before_render => sub {
        my ($c, $args) = (@_)
        $c->stash('timing.elapsed' => tv_interval($c->stash('timing.start')));
    });
}

1;
