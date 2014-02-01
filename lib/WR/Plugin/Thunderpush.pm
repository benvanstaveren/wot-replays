package WR::Plugin::Thunderpush;
use Mojo::Base 'Mojolicious::Plugin';
use WR::Thunderpush;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    $app->attr('thunderpush' => sub {
        WR::Thunderpush->new(
            host    => $conf->{host},
            key     => $conf->{key},
            secret  => $conf->{secret}
        );
    });
}

1;
