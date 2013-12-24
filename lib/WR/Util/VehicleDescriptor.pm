package WR::Util::VehicleDescriptor;
use Mojo::Base '-base';
use Data::Dumper;
use Scalar::Util qw/looks_like_number/;

use constant CUSTOMIZATION_EPOCH => 1306886400;

has [qw/descriptor nation vehicle chassis engine fueltank radio turret gun horn/] => undef;
has [qw/optional_devices/] => sub { [ undef, undef, undef ] };
has camo => sub { [] };
has [qw/emblems inscriptions/]=> sub { [ undef, undef, undef, undef ] };

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);
    bless($self, $package);

    die 'Missing descriptor', "\n" unless(defined($self->descriptor));
    $self->BUILD;
    return $self;
}

sub BUILD {
    my $self = shift;
    my $rest;

    (my $h, my $vtype, my $chassis, my $engine, my $fueltank, my $radio) = unpack('CCS<S<S<S<', substr($self->descriptor, 0, 10));

    $self->descriptor(substr($self->descriptor, 10));

    # this should, at some point, be turned into an array when multi-gun support happens.
    
    (my $turret, my $gun) = unpack('S<S<', substr($self->descriptor, 0, 4));

    $self->descriptor(substr($self->descriptor, 4));

    my $flags = (length($self->descriptor) >= 1) ? ord(substr($self->descriptor, 0, 1)) : 0;

    $self->descriptor(substr($self->descriptor, 1));
    
    $self->nation($h >> 4 & 15);
    $self->vehicle($vtype);
    $self->chassis($chassis);
    $self->engine($engine);
    $self->fueltank($fueltank);
    $self->radio($radio);

    # theoretically we can have multiple turrets, so ... this may need to be an arrayref at some point
    $self->turret($turret);
    $self->gun($gun);

    my $optional_devices_mask = $flags & 15;
    my $idx = 2;

    while($optional_devices_mask) {
        if($optional_devices_mask & 1) {
            my $m = unpack('S<', substr($self->descriptor, 0, 2));
            $self->descriptor(substr($self->descriptor, 2));
            $m = ord($m) if(looks_like_number($m) == 0);    # can't recall why this is here...
            $self->optional_devices->[$idx] = $m;
        } else {
            $self->optional_devices->[$idx] = undef;
        }
        $optional_devices_mask >>= 1;
        $idx--;
    }

    if($flags & 32) {
        my $positions = ord(substr($self->descriptor, 0, 1));
        $self->descriptor(substr($self->descriptor, 1));
        if($positions & 15) {
            for my $idx (0..3) {
                if($positions & 1 << $idx) {
                    $self->emblems->[$idx] = $self->unpack_id_and_duration(substr($self->descriptor, 0, 6));
                    $self->descriptor(substr($self->descriptor, 6));
                }
            }
        }
        if($positions & 240) {
            for my $idx (0..3) {
                if($positions & 1 << $idx + 4) {
                    (my $t, my $c) = unpack('A6C', substr($self->descriptor, 0, 7));
                    $self->descriptor(substr($self->descriptor, 7));
                    my $u = $self->unpack_id_and_duration($t);
                    push(@$u, $c);
                    $self->inscriptions->[$idx] = $u;
                }
            }
        }
        $self->_set_horn_id($flags & 64) if($flags & 64);
    }

    if($flags & 128) {
        while($self->descriptor) {
            my $t = unpack('A6', substr($self->descriptor, 0, 6));
            $self->descriptor(substr($self->descriptor, 6));
            push(@{$self->camo}, $self->unpack_id_and_duration($t));
        }
    }
}

sub unpack_id_and_duration {
    my $self = shift;
    my $r    = shift;

    return undef unless(defined($r));

    (my $id, my $times) = unpack('S<I<', $r);
    return undef unless(defined($id) && defined($times));
    return [ $id, ($times & 16777215) * 60 + CUSTOMIZATION_EPOCH, times >> 24 ];
}

sub to_hash {
    my $self = shift;

    return {
        nation => $self->nation,
        vehicle => $self->vehicle,
        chassis => $self->chassis,
        engine => $self->engine,
        fueltank => $self->fueltank,
        radio => $self->radio,
        turret => $self->turret,
        gun => $self->gun,
        optional_devices => $self->optional_devices,
        emblems =>  $self->emblems,
        inscriptions => $self->inscriptions,
        horn_id => $self->horn,
        camo => $self->camo,
        };
}

sub dump {
    my $self = shift;
    return Dumper($self->to_hash);
}

sub get_dict_descr {
    my $self = shift;

    my $item_type_id = $self->descriptor & 15;
    my $nation_id    = $self->descriptor >> 4 & 15;
    my $comp_type_id = $self->descriptor >> 8 & 65535;

    warn 'item_type_id: ', $item_type_id, "\n";
    warn 'nation_id...: ', $nation_id, "\n";
    warn 'comp_type_id: ', $comp_type_id, "\n";

    # there are getters that operate off the xml data which we obviously don't have available
    # to us right now

}

1;
