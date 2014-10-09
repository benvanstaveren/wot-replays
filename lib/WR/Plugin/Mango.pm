package WR::Plugin::Mango;
use Mojo::Base 'Mojolicious::Plugin';
use Mango;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    # set up the mango stuff here
    $app->attr(mango_conf => sub { $conf });
    $app->attr(mango => sub { Mango->new(shift->app->mango_conf->{host}) });
    $app->helper(get_database => sub {
        my $s = shift;
        my $d = $s->app->mango_conf->{database};
        return $s->app->mango->db($d);
    });
    $app->helper(model => sub {
        my $s = shift;
        my ($d, $c) = split(/\./, shift, 2);

        unless(defined($c)) {
            $c = $d ;
            $d = $s->app->mango_conf->{database},
        }

        return $s->app->mango->db($d)->collection($c);
    });
}

1;

