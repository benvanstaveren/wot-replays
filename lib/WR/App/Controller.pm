package WR::App::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub ui_cachable {
    my $self = shift;
    my %opts = (@_);

    my $ttl = $opts{'ttl'} || 120;

    if(my $obj = $self->db('wot-replays')->get_collection('ui.cache')->find_one({ _id => $opts{'key'} })) {
        return $obj->{res} unless($obj->{created} + $ttl < time());
    }

    my $method = $opts{'method'};
    if(my $res = $self->$method) {
        $self->db('wot-replays')->get_collection('ui.cache')->save({
            _id     => $opts{'key'},
            created => time(),
            res     => $res,
        });
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
