package WR::Parser::Stream::Packet::WOT::default::0x00;
use Mojo::Base 'WR::Parser::Stream::Packet';

# actually it's not the player ID at all, seems to be somehow related to the min or max level of 
# ID ranges - or perhaps the unique arena id or something similar
has 'player_id'         => sub { return shift->read(0, 4, 'L<') };
has 'player_name'       => sub { return shift->get_string(10) };
has 'player_name_length' => sub { 
    return shift->read(10, 1, 'C');
};

has 'arena_unique_id'   => sub { 
    my $self = shift;

    return $self->read(11 + $self->player_name_length, 8, 'Q');
};

has 'arena_type_id'     => sub {
    my $self = shift;

    return $self->read(11 + $self->player_name_length + 8, 4, 'L');
};

has 'bonus_type' => sub {
    my $self = shift;
    return $self->read(11 + $self->player_name_length + 12, 1, 'C');
};

has 'gui_type' => sub {
    my $self = shift;
    return $self->read(11 + $self->player_name_length + 13, 1, 'C');
};

has 'gameplay_id' => sub {
    return shift->arena_type_id >> 16;
};

has 'map_id' => sub {
    return shift->arena_type_id & 32767;
};

has 'payload_pickle' => sub {
    my $self = shift;
    my $key  = $self->read(11 + $self->player_name_length + 14, 1, 'C');
    my $pos  = 11 + $self->player_name_length + 14;

    if($key == 0xff) {
        # large pickle, usually means clan wars, we want to read a short, then pad the pos with 4 bytes

        my $length = $self->read($pos + 1, 2, 'S');

        # find the first occurrence of the pickle starter after $pos
        my $start_pos = $pos + 4;
        my $raw = $self->read($start_pos, $length);

        if(my $p = $self->safe_unpickle($raw, $self)) {
            return $p;
        } else {
            return undef;
        }
    } else {
        if(my $p = $self->safe_unpickle($self->get_string($pos), $self)) {
            return $p;
        } else {
            return undef;
        }
    }
};


has 'battle_level'  => sub {
    my $self = shift;

    return (defined($self->payload_pickle->{battleLevel})) ?  $self->payload_pickle->{battleLevel} + 0 : undef;
};

has 'opponents' => sub {
    my $self = shift;

    return (defined($self->payload_pickle->{opponents})) ?  $self->payload_pickle->{opponents} : undef;
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/player_id player_name player_name_length battle_level arena_unique_id arena_type_id gameplay_id map_id bonus_type gui_type payload_pickle opponents/);

    return $self;
}

1;
   
