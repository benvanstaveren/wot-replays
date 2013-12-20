package WR::Provider::Mapgrid;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;
use POSIX qw/floor/;

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
        die 'game_to_map_coord error: ', $_, "\n";
        $res = undef;
    };
    return $res;
}

sub coord_to_subcell_id {
    my $self = shift;
    my $c    = shift;

    $c = $self->game_to_map_coord($c) if(ref($c) eq 'ARRAY'); # raw data still in array form 

    my $x = ($c->{x} > 0) ? floor($c->{x} / $self->scellw) : 0;
    my $y = ($c->{y} > 0) ? floor($c->{y} / $self->scellw) : 0;

    return ($y * 100 ) + $x;
}

1;
