package WR::App::Controller::Heatmap;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub make_map_select {
    my $self = shift;
    my $cb   = shift;
    my $cursor = $self->model('wot-replays.data.maps')->find()->sort({ label => 1 })->all(sub {
        my ($coll, $err, $docs) = (@_);
        my $list = [];

        foreach my $doc (@$docs) {
            my $rec = {
                id      => $doc->{numerical_id},
                ident   => $doc->{_id},
                slug    => $doc->{slug},
                i18n    => $doc->{i18n},
                label   => $doc->{label},
                modes   => [ keys(%{$doc->{attributes}->{positions}}) ],
            };
            push(@$list, $rec);
        }
        $cb->($list);
    });
}

sub index {
    my $self = shift;

    $self->render_later;

    $self->make_map_select(sub {
        my $list = shift;
        $self->respond(
            template => 'heatmap/index',
            stash    => {
                map_list    =>  $list,
                pageid      => 'heatmap',
                page        => {
                    title => $self->loc('heatmaps.page.title'),
                },
            }
        );
    });
}

sub view {
    my $self        = shift;
    my $map_ident   = $self->stash('map_ident');
    my $mode        = $self->stash('mode');
    my $mmap        = { ctf => 0, domination => 1, assault => 2 };

    $self->render_later;

    $self->make_map_select(sub {
        my $list = shift;
        my $map  = undef;

        foreach my $entry (@$list) {
            $map = $entry and last if($entry->{slug} eq $map_ident);
        }
        $self->respond(
            template => 'heatmap/view',
            stash    => {
                map_list    =>  $list,
                map_id      => $map->{id},
                map_name    => $map->{label},
                map_ident   => $map->{ident},
                mode_id     => $mmap->{$mode},
                pageid => 'heatmap',
                page => {
                    title => sprintf('%s &raquo; %s', $self->loc('heatmaps.page.title'), $self->loc($map->{i18n})),
                },
            }
        );
    });
}

1;
