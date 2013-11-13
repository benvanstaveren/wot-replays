package WR::Provider::Wotlabs;
use Mojo::Base '-base';
use Mango::BSON;
use Try::Tiny qw/try catch/;
use Data::Dumper;

has 'ua' => undef;

sub get_class_from_rating {
    my $self = shift;
    my $rating = shift;
    my $class_map = [
        [ 0, 499, 'verybad' ],
        [ 500, 699, 'bad' ],
        [ 700, 899, 'belowaverage' ],
        [ 900, 1099, 'average' ],
        [ 1100, 1349, 'good' ],
        [ 1350, 1499, 'verygood' ],
        [ 1500, 1699, 'great' ],
        [ 1700, 1999, 'unicum' ],
        [ 2000, 99999, 'superunicum' ]
    ];

    foreach my $entry (@$class_map) {
        return $entry->[2] if($rating >= $entry->[0] && $rating <= $entry->[1]);
    }
    return 'unknown';
}

sub _fetch_one {
    my $self = shift;
    my $server = shift;
    my $player = shift;
    my $url  = sprintf('http://wotlabs.net/%s/player/%s', $server, $player);
    my $cb   = shift;

    warn 'fetch_one for ', $server, ' - ', $player, ' from ', $url, "\n";

    $self->ua->get($url => sub {
        my ($ua, $tx) = (@_);

        warn 'ua get cb', "\n";

        my $wn7 = {
            available => undef,
            class     => 'unknown',
            data => {
                last_24h => undef,          
                last_60d => undef,       
                overall  => undef,
            }
        };

        if(my $res = $tx->success) {
            warn 'success', "\n";
            if(my $table = $res->dom->at('table.generalStats')) {
                if(my $row = $table->find('tr')->[15]) {
                    try {
                        $wn7->{data}->{last_24h} = $row->find('td')->[2]->text + 0;
                        $wn7->{data}->{last_60d} = $row->find('td')->[5]->text + 0;
                        $wn7->{data}->{overall} = $row->find('td')->[1]->text + 0;
                        $wn7->{class} = $self->get_class_from_rating($wn7->{data}->{overall});
                        $wn7->{available} = Mango::BSON::bson_true;
                    } catch {
                        warn 'error in table scan', "\n";
                        $wn7->{available} = Mango::BSON::bson_false;
                        $wn7->{error} = $_;
                    };
                } else {
                    warn 'error in row scan', "\n";
                    $wn7->{available} = Mango::BSON::bson_false;
                }
            } else {
                warn 'error in document scan', "\n";
                $wn7->{available} = Mango::BSON::bson_false;
            }
        } else {
            warn 'tx failed', "\n";
            $wn7->{available} = Mango::BSON::bson_false;
        }
        $cb->($player => $wn7);
    });
}

sub fetch {
    my $self   = shift;
    my $server = shift;
    my $player = shift;
    my $cb     = shift;

    $player = [ $player ] unless(ref($player) eq 'ARRAY');

    use Data::Dumper;
    warn 'player: ', Dumper($player);

    warn 'set delay', "\n";
    my $delay = Mojo::IOLoop->delay(sub {
        my ($delay, @results) = (@_);
        my $res = {};
        foreach my $r (@results) {
            next unless(defined($r->{p}));
            $res->{$r->{p}} = $r->{w};
        }
        $cb->($res);
    });
    while(my $p = shift(@$player)) {
        warn 'fetching player ', $p, "\n";
        my $end = $delay->begin(0);
        $self->_fetch_one($server => $p, sub {
            my ($p, $w) = (@_);
            my $res = { p => $p, w => $w };
            warn 'WR::Wotlabs::_fetch_one returned with: ', Dumper($res), "\n";
            $end->($res);
        });
    }
    warn 'waiting delay?', "\n";
    $delay->wait unless(Mojo::IOLoop->is_running);
}

1;
