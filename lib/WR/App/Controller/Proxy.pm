package WR::App::Controller::Proxy;
use Mojo::Base 'WR::App::Controller';
use WR::Provider::Wotlabs::Cached;

sub wotlabs {
    my $self    = shift;
    my $server  = $self->stash('server');
    my $players = [ split(/,/, $self->stash('players')) ];

    $self->render_later;

    my $wotlabs = WR::Wotlabs::Cached->new(ua => $self->ua, cache => $self->model('wot-replays.cache.wotlabs'));
    $wotlabs->fetch($server => $players, sub { $self->render(json => shift) });
}

1;
