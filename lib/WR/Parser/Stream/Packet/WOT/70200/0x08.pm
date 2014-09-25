package WR::Parser::Stream::Packet::WOT::70200::0x08;
use Mojo::Base 'WR::Parser::Stream::Packet::WOT::default::0x08';

has 'player_id'         => sub { shift->_build_player_id };
sub _build_player_id { return shift->read(0, 4, 'L<') }

has 'data_length'       => sub { shift->_build_data_length };
sub _build_data_length { return shift->read(8, 4, 'L<') };

has 'update_type'       => sub { shift->_build_update_type };
sub _build_update_type { 
    my $self = shift; 
    return ($self->payload_size >= 13) 
        ? $self->read(12, 1, 'C') 
        : undef 
};

# chinky chink chink, arena updates
has 'update'            =>  sub { shift->_build_update };
sub _build_update {
    my $self = shift;

    if($self->subtype == 0x1d) { # onArena*
        my $length = $self->data_length;
        my $offset = 12;

        if($self->update_type == 0x01 || $self->update_type == 0x04) {
            $offset += 2;
            # urgh, depends on match type, the cheeseballer way is to check this:
            if($self->read($offset, 1, 'C') == 0x80 && $self->read($offset + 1, 1, 'C') == 0x02) {
                $length = $self->read($offset - 1, 1, 'C');
            } else {
                $offset = 12 + 5;
                $length = $self->data_length - 5;
            }
        }  else {
            $offset += 2;
            $length = $self->read($offset - 1, 1, 'C');
        }
        my $rawpickle = $self->read($offset, $length); # data length and the data type are excluded from this

        if(length($rawpickle) >= 3) { # empty pickle is 0x80 0x02 0x2e
            if(my $p = $self->safe_unpickle($rawpickle, $self)) {
                return $p;
            } else {
                return undef;
            }
        } else {
            return undef;
        }
    } else {
        return undef;
    }
};

has 'source'        => sub { shift->_build_source };
sub _build_source {
    my $self = shift;

    if($self->subtype == 0x01 || $self->subtype == 0x05 || $self->subtype == 0x0b) {
        my $pos = 12;
        $pos = 14 if($self->subtype == 0x01);
        $pos = 12 if($self->subtype == 0x0b);
        return $self->read($pos, 4, 'L<');
    } 
    return undef;
};

has 'target'        => sub { shift->_build_target };
sub _build_target {
    my $self = shift;

    if($self->subtype == 0x0b || $self->subtype == 0x17) {
        my $pos = ($self->subtype == 0x17) ? 14 : 10;
        return undef if($pos + 4 > $self->data_length);
        return $self->read($pos, 4, 'L<');
    }
    return undef;
};

has 'health'        => sub { shift->_build_health };
sub _build_health {
    my $self = shift;

    if($self->subtype == 0x01 || $self->subtype == 0x02) {
        return $self->read(12, 2, 'S<');
    }
    return undef;
};

has slot => sub { shift->_build_slot };
sub _build_slot {
    my $self = shift;

    if($self->subtype == 0x09) {
        my ($slot_item, $slot_count, $rest) = unpack('LSA*', $self->read(12, $self->data_length));
        return { item => $slot_item, count => $slot_count, rest => $rest };
    } else {
        return undef;
    }
};

has 'maybe_spot' => sub { shift->_build_maybe_spot };
sub _build_maybe_spot {
    my $self = shift;

    if($self->subtype == 0x0a) {
        my ($p1, $s, $p2) = unpack('LSL', $self->read(12, $self->data_length));
        return { p1 => $p1, s => $s, p2 => $p2 };
    } else {
        return undef;
    }
};

has 'byte_flag' => sub { shift->_build_byte_flag };
sub _build_byte_flag {
    my $self = shift;
    return $self->read($self->data_length -1, 1, 'C');
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id data_length/);

    $self->enable(qw/update_type update/) if($self->subtype == 0x1d);

    $self->enable('slot') if($self->subtype == 0x09);

    $self->enable('maybe_spot') if($self->subtype == 0x0a);

    if($self->subtype == 0x01) {
        $self->enable(qw/health source byte_flag/) 
    } else {
        $self->enable($_) for(qw/health target source/);
    }

    return $self;
}

1;
   
