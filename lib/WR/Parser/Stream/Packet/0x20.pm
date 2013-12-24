package WR::Parser::Stream::Packet::0x20;
use Mojo::Base 'WR::Parser::Stream::Packet';

has player_id => sub { return shift->read(0, 4, 'L<') };

has destroyed_track_id => sub { return shift->read(10, 1, 'C') };
has alt_track_state => sub { return shift->read(9, 1, 'C') };

sub BUILD {
    my $self = shift;

    $self->enable('player_id');
    $self->enable('destroyed_track_id', 'alt_track_state') if($self->alt_track_state == 0xf0 || $self->alt_track_state == 0xf6);

    return $self;
}

1;
   
