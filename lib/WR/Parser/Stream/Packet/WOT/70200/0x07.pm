package WR::Parser::Stream::Packet::WOT::70200::0x07;
use Mojo::Base 'WR::Parser::Stream::Packet::WOT::default::0x07';


has 'player_id'         => sub { shift->_build_player_id };
sub _build_player_id { return shift->read(0, 4, 'L<') }

has 'data_length'       => sub { shift->_build_data_length };
sub _build_data_length { return shift->read(8, 4, 'L<') }

has 'health'    => sub { shift->_build_health };
sub _build_health { 
    my $self = shift;

    if($self->subtype == 0x99) { # 0x99 for disabled properties
        return $self->read(12, 2, 'S<');
    } else {
        return undef;
    }
}

has 'destroyed_track_id' => sub { shift->_build_destroyed_track_id };
sub _build_destroyed_track_id { 
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
   
