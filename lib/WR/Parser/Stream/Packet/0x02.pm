package WR::Parser::Stream::Packet::0x02;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'player_id' => sub { return shift->read(0, 4, 'L<') };
has 'unknown'   => sub {
    my $self = shift;
    return sprintf('%02x ' x ($self->packet_size - 4), map { ord($_) } (split(//, substr($self->data, 4))));
};
has 'unknown_len' => sub {
    return length(shift->unknown);
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id unknown unknown_len/);   

    return $self;
}

1;
