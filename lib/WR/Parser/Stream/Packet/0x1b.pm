package WR::Parser::Stream::Packet::0x1b;
use Mojo::Base 'WR::Parser::Stream::Packet';

sub BUILD {
    my $self = shift;

    $self->enable;

    return $self;
}

1;
   
