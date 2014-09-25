package WR::Parser::Stream::Packet::WOT::default::0x19;
use Mojo::Base 'WR::Parser::Stream::Packet';

has unknown => sub { 
    my $self = shift;
    
    return {
        long    => unpack('L>', $self->payload),
        short   => unpack('S>2', $self->payload),
        bytes   => unpack('C4', $self->payload),
    }
};

sub BUILD {
    my $self = shift;

    $self->enable('unknown');

    return $self;
}

1;
