package WR::Parser::Stream::Packet::WOT::default::0x22;
use Mojo::Base 'WR::Parser::Stream::Packet';

# still unsure what this is, first appears when clock > 0 (but clock > 0 means we're in the countdown)

sub BUILD {
    my $self = shift;

    $self->enable;

    return $self;
}

1;
   
