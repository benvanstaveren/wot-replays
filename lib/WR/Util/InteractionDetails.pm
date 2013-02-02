package WR::Util::InteractionDetails;
use Moose;

has 'data' => (is => 'ro', isa => 'Str', required => 1);
has 'dict' => (is => 'ro', isa => 'HashRef', default => sub { {} }, traits => [qw/Hash/], handles => { 'set_dict' => 'set' });

use constant VEH_INTERACTION_DETAILS => [('spotted', 'killed', 'hits', 'he_hits', 'pierced', 'damageDealt', 'damageAssisted', 'crits', 'fire')];
use constant VEH_INTERACTION_DETAILS_INDICES => {
    0 => 'spotted',
    1 => 'killed',
    2 => 'hits',
    3 => 'he_hits',
    4 => 'pierced',
    5 => 'damageDealt',
    6 => 'damageAssisted',
    7 => 'crits',
    8 => 'fire'
};

sub BUILD {
    my $self = shift;

    my $size    = scalar(@{__PACKAGE__->VEH_INTERACTION_DETAILS});
    my $struct_size = 4 + ($size * 2);
    my $count   = length($self->data) / $struct_size;

    return if($count == 0);

    my @unpacked    = unpack(sprintf('L%dS*', $count), $self->data);
    my @vehicle_ids = splice(@unpacked, 0, $count);
    my @values      = @unpacked; # derp

    foreach my $vid (@vehicle_ids) {
        $self->dict->{$vid} = {};
        my @vidvalues = splice(@values, 0, $size);
        my $i = 0;
        while($i < $size) {
            $self->dict->{$vid}->{ __PACKAGE__->VEH_INTERACTION_DETAILS_INDICES->{$i} } = $vidvalues[$i] || 0;
            $i++;
        }
    }
    return $self;
}

sub TO_JSON {
    return shift->dict;
}

__PACKAGE__->meta->make_immutable;
