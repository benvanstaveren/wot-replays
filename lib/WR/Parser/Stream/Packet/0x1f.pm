package WR::Parser::Stream::Packet::0x1f;
use Mojo::Base 'WR::Parser::Stream::Packet';

has text      => sub {
    my $self = shift;
    return $self->get_long_string(0);
};

sub BUILD {
    my $self = shift;

    $self->enable($_) for(qw/text/);

    return $self;
}

1;
   
