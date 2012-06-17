package WR::App::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub cachable {
    my $self = shift;
    my %opts = (@_);

    use Data::Dumper;
    warn Dumper({%opts});

    my $ttl = $opts{'ttl'} || 120;

    if(my $obj = $self->db('wot-replays')->get_collection('ui.cache')->find_one({ _id => $opts{'key'} })) {
        return $obj->{value} unless($obj->{created} + $ttl < time());
    }

    my $method = $opts{'method'};
    if(my $res = $self->$method()) {
        warn 'called $self->', $method, '()', "\n";
        my $data = {
            _id     => $opts{'key'},
            created => time(),
            value   => $res || {},
        };
        warn 'saving data: ', Dumper($data), "\n";
        $self->db('wot-replays')->get_collection('ui.cache')->save($data, { safe => 1 });
        return $res;
    } else {
        return undef;
    }
}

sub respond {
    my $self = shift;
    my %args = (@_);
    my $stash = delete($args{'stash'});

    $self->stash(%$stash) if(defined($stash));
    if(my $start = $self->stash('timing.start')) {
        $self->stash('timing_elapsed' => Time::HiRes::tv_interval($start));
    }
    $self->render(%args);
}

1;
