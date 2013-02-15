package WR::App::Controller::Events;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Events;

sub index {
    my $self   = shift;

    for(qw/sea na eu/) {
        my $e = WR::Events->new(server => $_, db => $self->db('wot-replays'));
        $self->stash(sprintf('events_%s', $_) => $e->events);
    }

    $self->respond(
        template => 'event/index',
        stash    => {
            page => {
                title => 'Events',
            },
        }
    );
}

sub index_server {
    my $self = shift;
    my $s    = $self->stash('server');
    my $e    = WR::Events->new(server => $s, db => $self->db('wot-replays'));

    $self->respond(
        template => 'event/server',
        stash    => {
            page => {
                title => sprintf('%s - Events', $self->app->wr_res->servers->get($s, 'label_long')),
            },
            events => $e->events(all => 1),
        }
    );

}

sub view {
    my $self = shift;
    my $s    = $self->stash('server');
    my $eid  = $self->stash('eventid');
    my $e    = WR::Events->new(server => $s, db => $self->db('wot-replays'));

}

1;
