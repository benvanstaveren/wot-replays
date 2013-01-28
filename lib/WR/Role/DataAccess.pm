package WR::Role::DataAccess;
use Moose::Role;
use Try::Tiny;

has '_db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);

sub coll {
    my $self = shift;
    return $self->_db->get_collection(shift);
}

no Moose::Role;
1;
