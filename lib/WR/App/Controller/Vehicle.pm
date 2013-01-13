package WR::App::Controller::Vehicle;
use Mojo::Base 'WR::App::Controller';
use WR::Query;

sub index {
    my $self = shift;
    my $vehicles = {};

    foreach my $country (qw/china france germany uk usa ussr/) {
        my $temp = [];
        my $th   = {
            'L' => [],
            'M' => [],
            'H' => [],
            'S' => [],
            'T' => [],
        };

        my $cursor = $self->db('wot-replays')->get_collection('data.vehicles')->find({ country => $country })->sort({ level => 1 });
        while(my $obj = $cursor->next()) {
            push(@{$th->{$obj->{type}}}, {
                id => $obj->{_id},
                sid => $obj->{name},
            });
        }
        foreach (qw/L M H T S/) {
            push(@$temp, @{$th->{$_}});
        }
        $vehicles->{$country} = $th;
    }

    $self->respond(
        template => 'vehicle/index',
        stash => {
            page => { title => 'Vehicles' },
            vehicles_all => $vehicles,
            vehicletypes => [ 'L','M','H','T','S' ],
        },
    );
}

sub view {
    my $self = shift;
    my $country = $self->stash('country');
    my $vname   = $self->stash('vehicle');

    if(my $obj = $self->db('wot-replays')->get_collection('data.vehicles')->find_one({ _id => sprintf('%s:%s', $country, $vname) })) {
        $self->respond(
            template => 'vehicle/view',
            stash    => {
                vehicle_full => sprintf('%s:%s', $country, $vname),
                page => {
                    title => sprintf('Vehicles &raquo; %s', $obj->{label}),
                },
            }
        );
    } else {
        $self->respond(
            template => 'vehicle/notfound',
            stash => {
                page => { title => 'Not Found' } 
            },
        );
    }
}

1;
