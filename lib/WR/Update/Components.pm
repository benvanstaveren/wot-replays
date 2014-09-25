package WR::Update::Components;
use Mojo::Base '-base';
use Mojo::UserAgent;
use Data::Dumper;

has 'app' => undef;

sub run {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new;

    foreach my $type (qw/engines turrets radios chassis guns/) {
        if(my $tx = $ua->post(sprintf('https://api.statterbox.com/wot/encyclopedia/tank%s/', $type) => form => { cluster => 'asia', language => 'en', application_id => $self->app->config->{statterbox}->{server} })) {
            if(my $res = $tx->success) {
                die Dumper($res->json);
            } else {
                $self->app->log->error('Update::Components: could not fetch update for ' . $type . ' from encyclopedia: ' . Dumper($tx->error));
            }
        }
    }
}

1;
