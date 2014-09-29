package WR::Web::Site::Controller::Heatmap;
use Mojo::Base 'WR::Web::Site::Controller';
use boolean;

sub view {
    my $self        = shift;
    my $map_ident   = $self->stash('map_ident');

    $self->render_later;

    # find valid modes for the map
    $self->model('wot-replays.data.maps')->find_one({ slug => $map_ident } => sub {
        my ($c, $e, $map) = (@_);

        if(defined($map)) {
            my $modes = [ keys(%{$map->{attributes}->{positions}}) ];
            $self->respond(
                template => 'heatmap/view',
                stash    => {
                    map_id      => $map->{numerical_id},
                    map_name    => $self->loc($map->{i18n}),
                    map_ident   => $map->{_id},
                    modes       => $modes,
                    pageid => 'heatmap',
                }
            );
        }
    });
}

1;
