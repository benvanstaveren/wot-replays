package WR::Parser::Stream::Packet::0x14;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'version' => sub {
    return unpack('L/A', shift->payload);
};

sub BUILD {
    my $self = shift;

    $self->enable('version');

    return $self;
}

1;
   
