package WR::Parser::Stream::Packet::WOT::default::0x01;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'player_id' => sub { return shift->read(0, 4, 'L<') };
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

    $self->enable($_) for(qw/player_id unknown/);

    return $self;
}

1;
   
