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

    $res->{wpa} = {}; # just for the sake of sanity

    if(my $r = $coll->find_one({ _id => sprintf('%s-%s', $res->{player}->{vehicle}->{full}, $res->{map}->{id}) })) {
        $self->app->log->info('WPA: already have cached entry, checking expiry') if(defined($self->app));
        if($r->{created} + 86400 > time()) {
            $res->{wpa} = $r->{data};
            $self->app->log->info('WPA: added current entry to replay');
            return $res;
        }
        $self->app->log->info('WPA: entry expired') if(defined($self->app));
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

    $self->app->log->info('WPA: getting data from: ' . $url) if(defined($self->app));

    my $ua = Mojo::UserAgent->new();
    my $tx = $ua->get($url);
    if(my $response = $tx->success) {
        $self->app->log->info('WPA: fetch ok') if(defined($self->app));
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

            $self->app->log->info('WPA: added new entry to replay and stored in cache');
            $res->{wpa} = $data;
        }
    } else {
        if($self->app) {
            my ($err, $code) = $tx->error;
            $self->app->log->error('[WPA]: could not fetch data from vbaddict.net, url: ' . $url . ' response code: ' . $code . ' response error: ' . $err);
        }
    }
    return $res;
};

no Moose::Role;
1;
