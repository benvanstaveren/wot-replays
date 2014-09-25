package WR::Parser::Stream::Packet::WOT::default::0x1c;
use Mojo::Base 'WR::Parser::Stream::Packet';

sub BUILD {
    my $self = shift;
    
    $self->enable;

    return $self;
}

1;
   
