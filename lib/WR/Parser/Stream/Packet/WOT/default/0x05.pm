package WR::Parser::Stream::Packet::WOT::default::0x05;
use Mojo::Base 'WR::Parser::Stream::Packet';

# not sure what this one's doing, it has a large payload (63 bytes, usually); does not appear to hold a player id
# and there's a repeating pattern in the data that probably indicates a status of some sort, multiple 0x05's can come
# in on the same clock value

has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'data_length'       => sub { return shift->read(8, 4, 'L<') };
has 'unknown'   => sub {
    my $self = shift;
    my $u    = [];
    my $o    = 4;

    while($o + 4 < $self->payload_size) {
        push(@$u, $self->read($o, 4, 'L<'));
        $o += 4;
    }
    return $u;
};


sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id data_length unknown/);

    return $self;
}

1;
