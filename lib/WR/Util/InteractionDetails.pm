package WR::Util::InteractionDetails;
use Moose;

has 'data' => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
    my $self = shift;


}

__PACKAGE__->meta->make_immutable;
