package WR::Objects::Vehicle;
use Moose;

with qw/
    WR::Role::Serializable
    WR::Role::DataAccess
    /;

# fields in data
has 'id'            =>  (is => 'ro', isa => 'MongoDB::OID', required => 1);
has 'label'         =>  (is => 'ro', isa => 'Str', writer => '_set_label');
has 'label_short'   =>  (is => 'ro', isa => 'Str', writer => '_set_label_short');
has 'country'       =>  (is => 'ro', isa => 'Str', writer => '_set_label_country');
has 'description'   =>  (is => 'ro', isa => 'Str', writer => '_set_label_description');
has 'is_premium'    =>  (is => 'ro', isa => 'boolean', writer => '_set_is_premium');
has 'name'          =>  (is => 'ro', isa => 'Str', writer => '_set_name');
has 'name_lc'       =>  (is => 'ro', isa => 'Str', writer => '_set_name_lc');
has 'type'          =>  (is => 'ro', isa => 'Str', writer => '_set_type');
has 'level'         =>  (is => 'ro', isa => 'Num', writer => '_set_level');
has 'wot_id'        =>  (is => 'ro', isa => 'Num', writer => '_set_wot_id');
has 'wpa_country_id'=>  (is => 'ro', isa => 'Num', writer => '_set_wpa_country_id');
has 'wpa_tank_id'   =>  (is => 'ro', isa => 'Num', writer => '_set_wpa_tank_id');

sub BUILD {
    my $self = shift;

    $self->serializable(qw/id label label_short country description is_premium name name_lc type level wot_id wpa_country_id wpa_tank_id/);

    die 'no result from fetch' unless($self->load('vehicles' => { _id => $self->id }));
    return $self;
}

sub icon_url {
    my $self = shift;
   
} 

__PACKAGE__->meta->make_immutable;
