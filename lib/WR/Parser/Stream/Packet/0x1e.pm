package WR::Parser::Stream::Packet::0x1e;
use Mojo::Base 'WR::Parser::Stream::Packet';

has player_id => sub { return shift->read(0, 4, 'L<') };

sub BUILD {
    my $self = shift;

    $self->enable('player_id');

    return $self;
}

1;
   
