package WR::Parser::Stream::Packet::WOT::default::0x0a;
use Mojo::Base 'WR::Parser::Stream::Packet';

=pod

 0        4      8      12      16      20      24     28     32     36      40      44      48      49
 +--------+---------------------+-------+-------+------+------+------+-------+-------+-------+-------+
 | uint32 | .... | .... | float | float | float | .... | .... | .... | float | float | float | uint8 |
 +--------+------+------+-------+-------+-------+------+------+------+-------+-------+-------+-------+
   |        |     |      |                        |      |      |      |                       |
   |        |     |      |                        |      |      |      |                       ` unknown
   |        |     |      |                        |      |      |      |                      
   |        |     |      |                        |      |      |      ` hull orientation
   |        |     |      |                        |      |      ` unknown
   |        |     |      |                        |      ` unknown
   |        |     |      |                        ` unknown
   |        |     |      ` player position
   |        |     ` unknown
   |        ` unknown
   ` player_id

=cut

has 'position'          => sub {
    my $self = shift;

    return [
        $self->read(12, 4, 'f<') + 0.0,
        $self->read(16, 4, 'f<') + 0.0,
        $self->read(20, 4, 'f<') + 0.0,
    ];
};


has 'hull_orientation'  => sub {
    my $self = shift;

    return [
        $self->read(36, 4, 'f<') + 0.0,
        $self->read(40, 4, 'f<') + 0.0,
        $self->read(44, 4, 'f<') + 0.0,
    ];
};
has 'player_id' => sub {
    my $self = shift;

    return $self->read(0, 4, 'L<');
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/position hull_orientation player_id/);

    return $self;
}

1;
   
