package WR::Replay::Tagger;
use Moose;
use namespace::autoclean;

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);
has 'replay' => (is => 'ro', isa => 'HashRef', required => 1);

with 'WR::Role::Replay::Tagger';

sub tag {
    my $self   = shift;

    $self->tag_replay($self->replay);
}

1;
