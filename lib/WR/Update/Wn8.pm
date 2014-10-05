package WR::Update::Wn8;
use Mojo::Base 'WR::Update';
use Mojo::UserAgent;
use Data::Dumper;

sub run {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new;
    my $url  = 'http://www.wnefficiency.net/exp/expected_tank_values_latest.json';

    if(my $tx = $ua->get($url)) {
        if(my $res = $tx->success) {
            foreach my $v (@{$res->json('/data')}) {
                $self->app->mango->db('statterbox')->collection('wn8_expected')->save({
                    _id     => $v->{IDNum} + 0,
                    version => $res->json('/header/version'),
                    frags   => $v->{expFrag} + 0,
                    damage  => $v->{expDamage} + 0,
                    spot    => $v->{expSpot} + 0,
                    def     => $v->{expDef} + 0,
                    wr      => $v->{expWinRate} + 0,
                });
            }
            $self->app->log->debug('Update::Wn8: updated expected values');
        }
    } else {
        $self->app->log->error('Update::Wn8: could not fetch update from wnefficiency.net');
    }
}

1;
