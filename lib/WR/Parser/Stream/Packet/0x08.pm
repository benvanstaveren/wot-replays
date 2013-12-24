package WR::Parser::Stream::Packet::0x08;
use Mojo::Base 'WR::Parser::Stream::Packet';
use Data::Dumper;

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

has 'source_raw' => sub {
    my $self = shift;
    if($self->subtype == 0x01 || $self->subtype == 0x05 || $self->subtype == 0x0b) {
        my $pos = 12;
        $pos = 14 if($self->subtype == 0x01);
        $pos = 12 if($self->subtype == 0x0b);

        return $self->read_hex($pos, 4);
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

has 'health_raw' => sub {
    my $self = shift;

    if($self->subtype == 0x01 || $self->subtype == 0x02) {
        return $self->read_hex(12, 2);
    }
    return undef;
};

has 'target_raw'        => sub {
    my $self = shift;

    if($self->subtype == 0x0b || $self->subtype == 0x17) {
        my $pos = ($self->subtype == 0x17) ? 13 : 9;
        return undef if($pos + 4 > $self->data_length);
        return $self->read_hex($pos, 4);
    }
    return undef;
};


# these two are basically only there when subtype == 10,
# it's a slot item and it's count
has slot => sub {
    my $self = shift;

    if($self->subtype == 0x0a || $self->subtype == 0x09) {
        my ($slot_item, $slot_count, $dummy) = unpack('LLC', $self->read(12, $self->data_length));
        return { item => $slot_item, count => $slot_count };
    } else {
        return undef;
    }
};

sub dump {
    my $self = shift;

    return Dumper({ 
        payload   => $self->payload_hex,
        type      => $self->type,
        subtype   => $self->subtype,
        data_type => $self->data_type,
        data_length => $self->data_length,
    });
}

# subtype 0x14 seems to have something to do with base capture points 

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id data_length/);

    if($self->subtype == 0x1d) {
        $self->enable($_) for(qw/update_type update/);
    }
    
    $self->enable($_) for(qw/slot health target source/);
    $self->enable($_) for(qw/source_raw target_raw health_raw/);

    return $self;
}

1;
   
