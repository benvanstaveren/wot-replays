package WR::App::Controller::Heatmap;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub view {
    my $self        = shift;
    my $map_ident   = $self->stash('map_ident');
    my $mode        = $self->stash('mode');
    my $mmap        = { ctf => 0, domination => 1, assault => 2 };

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
                    map_name    => $map->{label},
                    map_ident   => $map->{_id},
                    mode_id     => $mmap->{$mode},
                    modes       => $modes,
                    pageid => 'heatmap',
                    page => {
                        title => sprintf('%s &raquo; %s', $self->loc('heatmaps.page.title'), $self->loc($map->{i18n})),
                    },
                }
            );
        }
    });
}

1;
