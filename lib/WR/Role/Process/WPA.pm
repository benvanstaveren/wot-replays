package WR::Role::Process::WPA;
use Moose::Role;
use WR::ServerFinder;
use Mojo::UserAgent;
use JSON::XS;
use Try::Tiny qw/catch try/;

# this isn't actually a process thing but
# it's used to flush the WPA cache 
# more or less "on-demand" for when a new replay is
# uploaded.
use constant WPA_GAME_MODE_MAPPING => {
    'ctf'           =>  0,
    'domination'    =>  256,
    'assault'       =>  512,
    };

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;
    my $coll = $self->db->get_collection('cache.wpa');

    if(my $r = $coll->find_one({ _id => sprintf('%s-%s', $res->{player}->{vehicle}->{full}, $res->{map}->{id}) })) {
        return $res if($r->{created} + 86400 > time());
    }

    my $map = $self->db->get_collection('data.maps')->find_one({ _id => $res->{map}->{id} });
    my $vehicle = $self->db->get_collection('data.vehicles')->find_one({ _id => $res->{player}->{vehicle}->{full} });
    my $j = JSON::XS->new();

    my $url = sprintf('http://www.vbaddict.net/api/1/2de35957abcde312ea8212d3cddfc168/%d/%d/%d/%d/',
        $vehicle->{wpa_tank_id},
        $vehicle->{wpa_country_id},
        $map->{wpa_map_id},
        WPA_GAME_MODE_MAPPING->{$res->{game}->{type}}
        );

    my $ua = Mojo::UserAgent->new();
    my $tx = $ua->get($url);
    if(my $response = $tx->success) {
        my $data = $j->decode($response->body);

        if($data->{result} eq 'OK') {
            $data = $data->{data};

            foreach my $k (keys(%$data)) {
                $data->{$k} += 0; # force numeric
            }

            $coll->save({ 
                _id => sprintf('%s-%s', $res->{player}->{vehicle}->{full}, $res->{map}->{id}),
                created => time(),
                data => $data
            });
        }
    }

    return $res;
};

no Moose::Role;
1;
