package WR::App::Controller::Vehicle;
use Mojo::Base 'WR::App::Controller';
use WR::Query;

sub index {
    my $self = shift;
    my $vehicles = {};

    $self->render_later;

    my $country = $self->stash('country');
    my $cursor = $self->model('wot-replays.data.vehicles')->find({ country => $country })->sort({ level => 1 });
    $cursor->all(sub {
        my ($c, $e, $d) = (@_);

        my $temp = [];
        my $th   = {
            'L' => [],
            'M' => [],
            'H' => [],
            'S' => [],
            'T' => [],
        };
        foreach my $obj (@$d) {
            next if($obj->{name} =~ /training/i);
            push(@{$th->{$obj->{type}}}, {
                id => $obj->{_id},
                sid => $obj->{name},
            });
        }
        foreach (qw/L M H T S/) {
            push(@$temp, @{$th->{$_}});
        }
        $self->stash(
            page => { title => 'Vehicles' },
            vehicles => $th,
            vehicletypes => [ 'L','M','H','T','S' ],
        );
        $self->respond(template => 'vehicle/index');
    });
}

sub view {
    my $self = shift;
    my $country = $self->stash('country');
    my $vname   = $self->stash('vehicle');

    if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => sprintf('%s:%s', $country, $vname) })) {
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
