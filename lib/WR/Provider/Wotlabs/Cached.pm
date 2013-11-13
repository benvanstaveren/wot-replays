package WR::Provider::Wotlabs::Cached;
use Mojo::Base 'WR::Provider::Wotlabs';

has 'cache' => undef; # should be a Mango::Collection

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    $self->ua->connect_timeout(5);
    $self->ua->inactivity_timeout(5);

    return $self;
}

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
                warn 'wotlabs: fetch_one ', $server, ' - ', $player, ' - cached entry expired', "\n";
                $self->SUPER::_fetch_one($server, $player, sub {
                    my ($p, $w) = (@_);
                    if($w->{available}) {
                        $self->cache->save({ _id => $url, ctime => Mango::BSON::bson_time, player => $p, wn7 => $w } => sub {
                            $cb->($p => $w);
                        });
                    } else {
                        $cb->($p => $w);
                    }
                });
            } else {
                warn 'wotlabs: fetch_one ', $server, ' - ', $player, ' - cached entry valid', "\n";
                $cb->($doc->{player} => $doc->{wn7});
            }
        } else {
            warn 'wotlabs: fetch_one ', $server, ' - ', $player, ' - no cached entry', "\n";
            $self->SUPER::_fetch_one($server, $player, sub {
                my ($p, $w) = (@_);

                if($w->{available}) {
                    $self->cache->save({ _id => $url, ctime => Mango::BSON::bson_time, player => $p, wn7 => $w } => sub {
                        my ($coll, $err, $oid) = (@_);
                        $cb->($p => $w);
                    });
                } else {
                    $cb->($p => $w);
                }
            });
        }
    });
}

1;
