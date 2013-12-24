package WR::Parser::Stream::Packet::0x05;
use Mojo::Base 'WR::Parser::Stream::Packet';

# not sure what this one's doing, it has a large payload (63 bytes, usually); does not appear to hold a player id
# and there's a repeating pattern in the data that probably indicates a status of some sort, multiple 0x05's can come
# in on the same clock value

sub BUILD {
    my $self = shift;

    $self->enable;

    return $self;
}

1;
