package WR::Parser::Stream::Packet::WOT::default::0x21;
use Mojo::Base 'WR::Parser::Stream::Packet';

# minimap cell clicked

has 'cell_id' => sub {
    return shift->read(0, 2, 'S');
};

has 'bv_cell_id' => sub {
    return 143 - shift->cell_id;
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/cell_id bv_cell_id/);

    return $self;
}
1;
