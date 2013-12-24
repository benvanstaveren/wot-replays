package WR::Util::ItemTypes;
use Mojo::Base '-base';
use WR::Util::TypeComp qw/parse_int_compact_descr/;

has 'item_type_names' => sub { 
    [qw/reserved vehicle vehicleChassis vehicleTurret vehicleGun vehicleEngine vehicleFuelTank vehicleRadio tankman optionalDevice shell equipment/]
};

has 'item_types_by_id' => sub {
    my $self = shift;
    my $i = 0;
    my $h = {};

    foreach my $type (@{$self->item_type_names}) {
        $h->{$i} = $type;
        $i++;
    }
    return $h;
};

has 'item_types_by_name' => sub {
    my $self = shift;
    my $i = 0;
    my $h = {};

    foreach my $type (@{$self->item_type_names}) {
        $h->{$type} = $i;
        $i++;
    }
    return $h;
};

sub make_int_descr_by_name {
    my $self   = shift;
    my $name   = shift;
    my $nation = shift;
    my $item   = shift;

    my $tid = $self->item_types_by_name->{$name} + 0;
    my $header = $tid + ($nation << 4);
    my $desc = ($item << 8) + $header;
    return $desc;
}

sub unpack_int_descr {
    my $self = shift;
    my $desc = shift;
    my $r = parse_int_compact_descr($desc);
    return { type => $r->{type_id}, nation => $r->{country}, id => $r->{id} };
}

sub get_item_type {
    my $self = shift;
    my $id   = shift;


    return $self->item_types_by_id->{$id};
}

1;
