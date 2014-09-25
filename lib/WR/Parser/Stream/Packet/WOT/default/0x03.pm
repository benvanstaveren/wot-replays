package WR::Parser::Stream::Packet::WOT::default::0x03;
use Mojo::Base 'WR::Parser::Stream::Packet';

# unsure what this packet is; the payload consists of 12 bytes
has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'u1'                => sub { return shift->read(4, 4, 'L<') };
has 'u2'                => sub { return shift->read(8, 4, 'L<') };

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id u1 u2/);

    return $self;
}

1;
   
