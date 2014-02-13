package WR::Parser::Stream::Packet::0x03;
use Mojo::Base 'WR::Parser::Stream::Packet';

# unsure what this packet is; the payload consists of 12 bytes
has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'unknown'           => sub { return shift->read(4, 8, 'L<L<') };

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id unknown/);

    return $self;
}

1;
   
