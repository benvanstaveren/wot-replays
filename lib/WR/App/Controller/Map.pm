package WR::App::Controller::Map;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self = shift;

    $map_list = [ $self->model('wot-replays.data.maps')->find()->sort({ label => 1 })->all() ];

    $self->respond(
        template => 'map/index',
        stash => {
            map_list => $map_list,
            page => { title => 'Maps' },
        },
    );
}

sub view {
    my $self   = shift;
    my $map_id = $self->stash('map_id');

    my $m_obj = $self->model('wot-replays.data.maps')->find_one({ slug => $map_id });

    $self->respond(
        template => 'map/view',
        stash    => {
            page => {
                title => sprintf('Maps &raquo; %s', $m_obj->{label}),
            },
        }
    );
}

1;
