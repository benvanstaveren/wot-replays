package WR::Efficiency;
use Moose;

has 'killed'  => (is => 'ro', isa => 'Num', required => 1);
has 'spotted' => (is => 'ro', isa => 'Num', required => 1);
has 'damaged' => (is => 'ro', isa => 'Num', required => 1);
has 'tier'    => (is => 'ro', isa => 'Num', required => 1);

has 'damage_direct'  => (is => 'ro', isa => 'Num', required => 1);
has 'damage_spotted' => (is => 'ro', isa => 'Num', required => 1);

has 'winrate' => (is => 'ro', isa => 'Num', required => 1);
has 'defense_points' => (is => 'ro', isa => 'Num', required => 1);

__PACKAGE__->meta->make_immutable;
