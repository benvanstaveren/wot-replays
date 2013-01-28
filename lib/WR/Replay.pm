package WR::Replay;
use Moose;
use boolean;
use WR::Res;

with qw/WR::Role::DataAccess/;

has 'efficiency'        => (is => 'ro', isa => 'HashRef',       required => 1, default => sub { {} });
has 'vehicles'          => (is => 'ro', isa => 'HashRef',       required => 1);
has 'teams'             => (is => 'ro', isa => 'ArrayRef',      required => 1);
has 'statistics'        => (is => 'ro', isa => 'HashRef',       required => 1);
has '_id'               => (is => 'ro', isa => 'MongoDB::OID',  required => 1);
has 'players'           => (is => 'ro', isa => 'HashRef',       required => 1);
has 'file'              => (is => 'ro', isa => 'Str',           required => 1);
has 'component_attributes' 
                        => (is => 'ro', isa => 'HashRef',       required => 1);
has 'map'               => (is => 'ro', isa => 'HashRef',       required => 1);
has 'platoons'          => (is => 'ro', isa => 'HashRef',       required => 1, default => sub { {} });
has 'version'           => (is => 'ro', isa => 'Str',           required => 1);
has 'version_full'      => (is => 'ro', isa => 'Str',           required => 1);
has 'player'            => (is => 'ro', isa => 'HashRef',       required => 1);
has 'chat'              => (is => 'ro', isa => 'ArrayRef',      required => 1, default => sub { [] });
has 'replay_digest'     => (is => 'ro', isa => 'Str',           required => 1);
has 'site'              => (is => 'ro', isa => 'HashRef',       required => 1);
has 'game'              => (is => 'ro', isa => 'HashRef',       required => 1);
has 'vehicle_fittings'  => (is => 'ro', isa => 'HashRef',       required => 1);
has 'complete'          => (is => 'ro', isa => 'boolean',       required => 1);

# cheesy alias
sub id { return shift->_id }

sub BUILD {
    my $self = shift;


}




__PACKAGE__->meta->make_immutable;
