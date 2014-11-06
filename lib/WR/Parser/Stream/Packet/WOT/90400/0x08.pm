package WR::Parser::Stream::Packet::WOT::90400::0x08;
use Mojo::Base 'WR::Parser::Stream::Packet';
use Try::Tiny qw/try catch/;

has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'data_length'       => sub { return shift->read(8, 4, 'L<') };
has 'update_type'       => sub { 
    my $self = shift; 
    return ($self->payload_size >= 13) 
        ? $self->read(12, 1, 'C') 
        : undef 
};

# chinky chink chink, arena updates
has 'update'            =>  sub {
    my $self = shift;

    if($self->subtype == 0x1e) { # onArena*
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
        } else {
            $offset += 2;
            $length = $self->read($offset - 1, 1, 'C');
            if($length > $self->data_length) {
                return undef;
            }
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

    return undef;
};

has 'source'        => sub {
    my $self = shift;
    if($self->subtype == 0x01 || $self->subtype == 0x05 || $self->subtype == 0x06 || $self->subtype == 0x0b) {
        my $pos = 12;
        $pos = 14 if($self->subtype == 0x01);
        $pos = 12 if($self->subtype == 0x0b);
        return $self->read($pos, 4, 'L<');
    } 
    return undef;
};

has 'target'        => sub {
    my $self = shift;

    if($self->subtype == 0x0b || $self->subtype == 0x17) {
        my $pos = ($self->subtype == 0x17) ? 14 : 10;
        return undef if($pos + 4 > $self->data_length);
        return $self->read($pos, 4, 'L<');
    }
    return undef;
};

has 'health'        => sub {
    my $self = shift;

    if($self->subtype == 0x01 || $self->subtype == 0x02) {
        return $self->read(12, 2, 'S<');
    }
    return undef;
};

has slot => sub {
    my $self = shift;

    if($self->subtype == 0x09) {
        my ($slot_item, $slot_count, $rest) = unpack('LSA*', $self->read(12, $self->data_length));
        return { item => $slot_item, count => $slot_count, rest => $rest };
    } else {
        return undef;
    }
};

has 'maybe_spot' => sub {
    my $self = shift;

    if($self->subtype == 0x0a) {
        my ($p1, $s, $p2) = unpack('LSL', $self->read(12, $self->data_length));
        return { p1 => $p1, s => $s, p2 => $p2 };
    } else {
        return undef;
    }
};

# subtype 0x06 has a source, followed by:
# 01 00 00 00 03 01 ff 2a 91 c3 36 8f 02
# S    S      L           L           C

# related to avatar.showVehicleDamageInfo(self, vehicleID, damageIndex, extraIndex, entityId)
has 'subtype_06_data' => sub {
    my $self = shift;
    return [ unpack('SSLLC', $self->read(16, $self->data_length - 4)) ]
};

has 'byte_flag' => sub {
    my $self = shift;
    return $self->read($self->data_length -1, 1, 'C');
};

sub BUILD {
    my $self = shift;

    try {
        $self->enable($_) for(qw/player_id data_length/);
        $self->enable(qw/update_type update/) if($self->subtype == 0x1d);
        $self->enable('slot') if($self->subtype == 0x09);
        $self->enable('maybe_spot') if($self->subtype == 0x0a);
        $self->enable('subtype_06_data') if($self->subtype == 0x06);

        if($self->subtype == 0x01) {
            $self->enable(qw/health source byte_flag/) 
        } else {
            $self->enable($_) for(qw/health target source/);
        }
    } catch {
        die 'Failed to parse 0x08 properly, subtype is: ', sprintf('%02x', $self->subtype), "\n";
    };

    return $self;
}

1;
   
