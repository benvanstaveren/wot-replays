package WR::Parser::Stream::Packet::WOT::default::0x0b;
use Mojo::Base 'WR::Parser::Stream::Packet';

has 'space' => sub {
    my $self = shift;
    my $sidx = index($self->payload, 'spaces/');
    my $space = substr($self->payload, $sidx + 7);
    return $space;
};

sub BUILD {
    my $self = shift;

    $self->enable('space');

    return $self;
}

1;
   
