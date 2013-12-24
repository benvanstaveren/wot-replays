package WR::Parser::Stream::Packet::0x17;
use Mojo::Base 'WR::Parser::Stream::Packet';

# view mode change
has 'viewmode' => sub {
    return shift->get_long_string(0);
};

sub BUILD {
    my $self = shift;

    $self->enable('viewmode');

    return $self;
}

1;
   
