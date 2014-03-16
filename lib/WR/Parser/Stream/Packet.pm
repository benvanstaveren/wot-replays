package WR::Parser::Stream::Packet;
use Mojo::Base '-base';
use WR::Util::Pickle;
use Data::Dumper;
use Try::Tiny qw/try catch/;

# properties are no longer set in stone since they can vary their position based on the position inside the packet,
# instead each packet type has it's own module, if that module isn't present, we don't know about the packet. 
# this class provides the base mechanics for extracting data.
#
#
# packet layout:
#
# uint32    payload size    (0, 4)
# uint32    packet type     (4, 4)
# uint32    clock           (8, 4) but this is a bit tentative
# variable  payload         (12, ...)

has data            => undef;
has packet_size     => sub { return length(shift->data) };
has packet_offset   => 0;

has direct          => undef;

has payload_size    => sub { return unpack('L<', substr(shift->data, 0, 4)) };
has payload         => sub { 
    my $self = shift;
    return ($self->payload_size > 0) ? substr($self->data, 12, $self->payload_size) : undef;
};

has payload_hex     => sub {
    my $self = shift;

    if(my $payload = $self->payload) {
        return sprintf('%02x ' x $self->payload_size, (map { ord($_) } (split(//, $self->payload))));
    } else {
        return undef;
    }
};

has has_properties  => 0;           # set to 0 because defaults aren't included

has type            => sub { return unpack('L<', substr(shift->data, 4, 4)) };
has clock           => sub { 
    my $self = shift;
    my $cstr = substr($self->data, 8, 4);

    if(length($cstr) == 4) {
        return unpack('f<', $cstr);
    } else {
        return undef;
    }
};
has subtype         => sub { 
    my $self = shift;
    
    if(length($self->data) >= 20) {
        return unpack('L<', substr($self->data, 16, 4));
    } else {
        return undef;
    }
};

has properties      => sub { 
    {
        payload_size => 1,
        type => 1,
        clock => 1,
        subtype => 1,
    }
};

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    return $self->BUILD;
}

sub disable {
    my $self = shift;

    foreach my $name (@_) {
        delete($self->properties->{$name});
    }
}

sub enable {
    my $self = shift;

    foreach my $name (@_) {
        $self->has_properties(1);
        $self->properties->{$name} = 1 if(defined($name));
    }
}

sub dump { return Dumper(shift) }
sub to_hash {
    my $self = shift;
    my $h    = {};
    
    foreach my $key (keys(%{$self->properties})) {
        $h->{$key} = $self->$key();
    }

    $h->{direct}  = $self->direct;
    $h->{payload} = $self->payload_hex;

    return $h;
}

sub TO_JSON { shift->to_hash }

sub read {
    my $self = shift;
    my $o    = shift;
    my $l    = shift;
    my $f    = shift;

    die ref($self), ': unsafe read, requested ', $l, ' bytes at offset ', $o, ', would require ', $o + $l, ' bytes of data, but length of payload only ', $self->payload_size, "\n" if($o + $l > $self->payload_size);
    my $raw = substr($self->payload, $o, $l);
    return (defined($f)) ? unpack($f, $raw) : $raw;
}

sub read_hex {
    my $self = shift;
    my $o    = shift;
    my $l    = shift;

    return sprintf('%02x ' x $l, unpack('C' x $l, $self->read($o, $l)));
}

sub get_long_string {
    my $self   = shift;
    my $offset = shift;

    return unpack('L/A', substr($self->payload, $offset));
}

sub get_short_string {
    my $self   = shift;
    my $offset = shift;

    return unpack('S/A', substr($self->payload, $offset));
}

sub get_string {
    my $self   = shift;
    my $offset = shift;

    return unpack('C/A', substr($self->payload, $offset));
}

sub safe_unpickle {
    my $self = shift;
    my $data = shift;
    my $source = shift;
    my $p    = undef;

    try {
        $p = WR::Util::Pickle->new(data => $data)->unpickle;
    } catch {
        my $e = $_;
        chomp($e);
        print '[safe_unpickle in ', ref($self), ']: len: ', length($data), ' - failed: ', $e, "\n";
        print 'dump: ', $source->dump, "\n";
        $p = undef;
    };
    return $p;
}

1;
