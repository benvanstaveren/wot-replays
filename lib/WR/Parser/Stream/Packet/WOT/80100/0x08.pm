package WR::Parser::Stream::Packet::WOT::80100::0x08;
use Mojo::Base 'WR::Parser::Stream::Packet::WOT::default::0x08';


has 'source'        => sub {
    my $self = shift;
    if($self->subtype == 0x01 || $self->subtype == 0x05 || $self->subtype == 0x06 || $self->subtype == 0x0b) {
        my $pos = 12;
        #$pos = 14 if($self->subtype == 0x01);
        #$pos = 12 if($self->subtype == 0x0b);
        return $self->read($pos, 4, 'L<');
    } 
    return undef;
};

1;
