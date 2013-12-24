package WR::Parser::Stream::Packet::0x03;
use Mojo::Base 'WR::Parser::Stream::Packet';

# unsure what this packet is; the payload consists of 
# an uint32 that keeps changing, followed by what seems to be a fixed
# sequence of 07 09 00 00 00 00 00 00 - probably 2 uint32's or 4 uint16's

sub BUILD {
    my $self = shift;

    $self->enable;

    return $self;
}

1;
   
