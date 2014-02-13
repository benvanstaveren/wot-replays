package WR::Plugin::Statterpush;
use Mojo::Base 'Mojolicious::Plugin';
use WR::Statterpush::Server;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    $app->attr('statterpush' => sub {
        WR::Statterpush::Server->new(token => $conf->{token}, group => $conf->{group}, host => 'api.statterbox.com');
    });
    $app->log->info('Registered Statterpush plugin using token: ' . $conf->{token} . ' and group ' . $conf->{group});
}

1;
