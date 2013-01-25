package WR::Intel::Clan;
use Moose;
use Mojo::UserAgent;

has 'db'      => (is => 'ro', isa => 'Mongo::Database', required => 1);
has 'clan_id' => (is => 'ro', isa => 'Num', required => 1);
has 'data'    => (is => 'ro', isa => 'HashRef', required => 1, default => sub { {} }, writer => '_set_data');

sub BUILD {
    my $self = shift;

    if(my $clan = $self->db->get_collection('intel.clan')->find_one({ _id => $self->clan_id + 0 })) {
        $self->_set_data($clan);
    } 
}

sub needs_refresh {
    my $self = shift;

    return ($self->data->{meta}->{refreshed} + 86400 < time()) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;
