package WR::Provider::Mapgrid;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;

has 'bounds' => sub { [] }; 
has 'width'  => 0;
has 'height' => 0;

has cellw   =>  sub { shift->width / 10 };
has cellh   =>  sub { shift->height / 10 };
has scellw  =>  sub { shift->width / 100 };
has scellh  =>  sub { shift->width / 100 };

sub game_to_map_coord {
    my $self = shift;
    my $p    = shift;
    my $res;

    try {
        my $x = ($p->[0] - $self->bounds->[0]->[0]) * ($self->width / ($self->bounds->[1]->[0] - $self->bounds->[0]->[0] + 1));
        my $y = ($self->bounds->[1]->[1] - $p->[2]) * ($self->height / ($self->bounds->[1]->[1] - $self->bounds->[0]->[1] + 1));
        $res = { x => $x, y => $y };
    } catch {
        $res = undef;
    };
    return $res;
}

sub coord_to_cell_id {
    my $self = shift;
    my $c    = shift;

    return (int($c->{y} / $self->cellh) * 10) + int($c->{x} / $self->cellw);
}

sub coord_to_subcell_id {
    my $self = shift;
    my $c    = shift;

    return (int($c->{y} / $self->cellh) * 100) + int($c->{x} / $self->cellw);
}

sub get_subcell_center_coordinates {
    my $self = shift;
    my $c    = shift;

    # coords between 0 and 768, divide by scellw to get offset
    my $x = ($c->{x} > 0) ? int($c->{x} / $self->scellw) : 0;
    my $y = ($c->{y} > 0) ? int($c->{y} / $self->scellh) : 0;

    my $sx = $x * $self->scellw + ($self->scellw / 2);
    my $sy = $y * $self->scellh + ($self->scellh / 2);

    $sx = $self->width - ($sx - $self->width) if($sx > $self->width);
    $sy = $self->height - ($sy - $self->height) if($sy > $self->height);

    return { x => int($sx), y => int($sy) };
}

1;
