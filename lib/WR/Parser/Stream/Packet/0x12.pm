package WR::Parser::Stream::Packet::0x12;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'unknown' => sub {
    return unpack('L<', shift->payload);
};

sub BUILD {
    my $self = shift;

    $self->enable('unknown');

    return $self;
}

1;
   
