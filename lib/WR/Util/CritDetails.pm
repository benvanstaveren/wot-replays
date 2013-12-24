package WR::Util::CritDetails;
use Mojo::Base '-base';
use WR::Constants qw//;

# strangely enough, the crits now contain the mask of things that got zapped
# so... yeha.
has 'crit' => undef;

sub parse {
    my $self = shift;
    my $crits = $self->crit;

    my $destroyed_tankmen = $crits >> 24 & 255;
    my $destroyed_devices = $crits >> 12 & 4095;
    my $critical_devices  = $crits & 4095;
    
    my $count = 0;
    my $c_dev_list = [];
    my $d_dev_list = [];
    my $d_tm_list = [];

    for(my $i = 0; $i < scalar(@{WR::Constants->VEHICLE_DEVICE_TYPE_NAMES}); $i++) {
        if(1 << $i & $critical_devices) {
            $count++;
            push(@$c_dev_list, WR::Constants->VEHICLE_DEVICE_TYPE_NAMES->[$i]);
        }
        if(1 << $i & $destroyed_devices) {
            $count++;
            push(@$d_dev_list, WR::Constants->VEHICLE_DEVICE_TYPE_NAMES->[$i]);
        }
    } 

    for(my $i = 0; $i < scalar(@{WR::Constants->VEHICLE_TANKMAN_TYPE_NAMES}); $i++) {
        if(1 << $i & $destroyed_tankmen) {
            $count++;
            push(@$d_tm_list, WR::Constants->VEHICLE_TANKMAN_TYPE_NAMES->[$i]);
        }
    }

    return {
        count => $count,
        critical_devices => $c_dev_list,
        destroyed_devices => $d_dev_list,
        destroyed_tankmen => $d_tm_list,
    };
}

1;
