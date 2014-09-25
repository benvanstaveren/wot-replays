package WR::Parser::Stream::Packet::WOT::default::0x07;
use Mojo::Base 'WR::Parser::Stream::Packet';

# subtypes seen: 0x00, 0x02, 0x03, 0x04, 0x07
#
# seems to deal with destroyed or damaged modules, there's more in the payload, however, most of the time
#
# 0     4           player_id
# 4     4           subtype
# 8 ..  x           data


has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'data_length'       => sub { return shift->read(8, 4, 'L<') };

has 'health'    => sub { 
    my $self = shift;

    if($self->subtype == 0x03) {
        return $self->read(12, 2, 'S<');
    } else {
        return undef;
    }
};

has 'destroyed_track_id' => sub { 
    my $self = shift;
    if($self->subtype == 0x07) {
        return $self->read(16, 1, 'C') if($self->read(6, 4, 'L<') == 0x05);
        return undef;
    } else {
        return undef;
    }
};

sub BUILD {
    my $self = shift;

    $self->enable(qw/player_id data_length/);
    $self->enable($_) for(qw/health destroyed_track_id/);

    return $self;
}

1;
   
