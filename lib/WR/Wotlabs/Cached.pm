package WR::Wotlabs::Cached;
use Mojo::Base 'WR::Wotlabs';

has 'cache' => undef; # should be a Mango::Collection

sub _fetch_one {
    my $self   = shift;
    my $server = shift;
    my $player = shift;
    my $url    = sprintf('http://wotlabs.net/%s/player/%s', $server, $player);
    my $cb     = shift;

    $self->cache->find_one({ _id => $url } => sub {
        my ($coll, $err, $doc) = (@_);
        if(defined($doc)) {
            if($doc->{ctime} + (86400 * 1000) < Mango::BSON::bson_time) {
                $self->SUPER::_fetch_one($server, $player, sub {
                    my ($p, $w) = (@_);
                    $self->cache->save({ _id => $url, ctime => Mango::BSON::bson_time, player => $p, wn7 => $w } => sub {
                        $cb->($p => $w);
                    });
                });
            } else {
                $cb->($doc->{player} => $doc->{wn7});
            }
        } else {
            $self->SUPER::_fetch_one($server, $player, sub {
                my ($p, $w) = (@_);
                $self->cache->save({ _id => $url, ctime => Mango::BSON::bson_time, player => $p, wn7 => $w } => sub {
                    my ($coll, $err, $oid) = (@_);
                    $cb->($p => $w);
                });
            });
        }
    });
}

1;
