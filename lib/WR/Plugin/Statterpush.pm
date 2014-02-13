package WR::Plugin::Statterpush;
use Mojo::Base 'Mojolicious::Plugin';
use WR::Statterpush::Server;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    $app->attr('statterpush' => sub {
        WR::Statterpush::Server->new(token => $conf->{token}, group => 'wotreplays', host => 'api.statterbox.com');
    });
}

1;
