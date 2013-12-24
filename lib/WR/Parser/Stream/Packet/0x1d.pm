package WR::Parser::Stream::Packet::0x1d;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'unknown' => sub { [] };

sub BUILD {
    my $self = shift;

    $self->unknown([ unpack('LLC', $self->payload) ]);
    $self->enable('unknown');

    return $self;
}

1;
   
