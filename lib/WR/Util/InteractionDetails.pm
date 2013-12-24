package WR::Util::InteractionDetails;
use Mojo::Base '-base';

has data => undef;
has dict => sub { {} };

# a quite literal port of common/battle_results_shared.py

use constant VEH_INTERACTION_DETAILS => [
    [ 'spotted', 'C<', 1, 0 ],
    [ 'deathReason', 'c<', 10, -1 ],
    [ 'hits', 'S<', 65535, 0 ],
    [ 'he_hits', 'S<', 65535, 0 ],
    [ 'pierced', 'S<', 65535, 0 ],
    [ 'damageDealt', 'S<', 65535, 0 ],
    [ 'damageAssistedTrack', 'S<', 65535, 0 ],
    [ 'damageAssistedRadio', 'S<', 65535, 0 ],
    [ 'crits', 'I<', 4294956295, 0 ],
    [ 'fire', 'S<', 65535, 0 ],

use constant VEH_INTERACTION_DETAILS_NAMES => [ map { $_->[0] } for(@{__PACKAGE__->VEH_INTERACTION_DETAILS}) ];
use constant VEH_INTERACTION_DETAILS_MAX_VALUES => { map { $_->[0] => $_->[2] } for(@{__PACKAGE__->VEH_INTERACTION_DETAILS}) };
use constant VEH_INTERACTION_DETAILS_INIT_VALUES => { map { $_->[0] => $_->[3] } for(@{__PACKAGE__->VEH_INTERACTION_DETAILS}) };
use constant VEH_INTERACTION_DETAILS_LAYOUT => join('', $_) for(@{__PACKAGE__->VEH_INTERACTION_DETAILS});
use constant VEH_INTERACTION_DETAILS_INDICES => {'spotted' => 0, 'hits' => 2, 'damageAssistedTrack' => 6, 'fire' => 9, 'deathReason' => 1, 'damageDealt' => 5, 'crits' => 8, 'pierced' => 4, 'damageAssistedRadio' => 7, 'he_hits' => 3};

# this is calculated on the fly in battle_results_shared but made it a constant here
use constant STRUCT_SIZE => 24;

sub new {
    my $package = shift;
    my $self = $package->SUPER::new(@_);
    bless($self, $package);

    $self->BUILD;
    return $self;
}

sub BUILD {
    my $self = shift;
    my $struct_size = 24;
    my $count       = length($self->data) / $struct_size;

    return if($count == 0);

    my $packedvehidslayout = 'I>' x $count;
    my $packedvehidslen    = 4 * $count; # int = 4 bytes

    my @vehicle_ids = unpack($packedvehidslayout, substr($self->data, 0, $packedvehidslen));
    my @values      = unpack($self->VEH_INTERACTION_DETAILS_LAYOUT x $count, substr($self->data, $packedvehidslen));

    foreach my $vid (@vehicle_ids) {
        # FIXME FIXME sort this out later given that vehicle details aren't easily accessible anymore
    }
    return $self;
}

sub TO_JSON {
    return shift->dict;
}

1;
