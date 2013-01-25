package WR::Role::DataAccess;
use Moose::Role;
use Try::Tiny;

has '_db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);

sub fetch {
    my $self = shift;
    my $coll = shift;
    my $query = shift;

    if(my $data = $self->_db->get_collection($coll)->find_one($query)) {
        foreach my $key (keys(%$data)) {
            if($self->can($key)) {
                $self->$key($data->{$key});
            }
        }
    }
}

no Moose::Role;
1;
