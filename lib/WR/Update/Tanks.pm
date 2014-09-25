package WR::Update::Tanks;
use Mojo::Base '-base';
use Mojo::UserAgent;

has 'app' => undef;

sub run {
    my $self = shift;
    use Data::Dumper;

    die Dumper($self->app->config);
}

1;

