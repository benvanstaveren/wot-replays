package WR::App::Controller::Map;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self = shift;

    $self->render_later;
    $self->model('wot-replays.data.maps')->find()->sort({ label => 1 })->all(sub {
        my ($c, $e, $map_list) = (@_);
        $self->respond(
            template => 'map/index',
            stash => {
                map_list => $map_list,
                page => { title => 'Maps' },
            },
        );
    });
}

sub heatmap {
    my $self        = shift;
    my $map_ident   = $self->stash('map_ident');

    $self->render_later;
    $self->model('wot-replays.data.maps')->find_one({ slug => $map_ident } => sub {
        my ($c, $e, $m_obj) = (@_);
        $self->respond(
            template => 'heatmap/index',
            stash    => {
                map_id   => $m_obj->{numerical_id},
                map_name => $m_obj->{label},
                map_ident => $m_obj->{_id},
                pageid => 'heatmap',
                page => {
                    title => sprintf('Maps &raquo; %s &raquo; Heatmap', $m_obj->{label}),
                },
            }
        );
    });
}

sub view {
    my $self   = shift;
    my $map_id = $self->stash('map_id');

    $self->render_later;

    $self->model('wot-replays.data.maps')->find_one({ slug => $map_id } => sub {
        my ($c, $e, $m_obj) = (@_);
        $self->respond(
            template => 'map/view',
            stash    => {
                page => {
                    title => sprintf('Maps &raquo; %s', $m_obj->{label}),
                },
            }
        );
    });
}

1;
