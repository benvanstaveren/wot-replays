package WR::App::Controller::Events;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Events;

sub index {
    my $self   = shift;

    for(qw/sea na eu/) {
        my $e = WR::Events->new(server => $_, db => $self->db('wot-replays'));
        $self->stash(sprintf('events_%s', $_) => $e->events(all => 1));
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

    my $res  = $e->event($eid);
    
    $self->respond(
        template => 'event/view',
        stash    => {
            page => {
                title => sprintf('%s - %s - Events', $res->{event}->{name}, $self->app->wr_res->servers->get($s, 'label_long')),
            },
            event   => $res->{event},
            servername => $self->app->wr_res->servers->get($s, 'label_long'),
            replays => [ map { WR::Query->fuck_tt($_) } $res->{cursor}->sort({ 'game.time' => -1 })->all() ],
        }
    );

}

1;
