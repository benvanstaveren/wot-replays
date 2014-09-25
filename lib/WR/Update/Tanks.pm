package WR::Update::Tanks;
use Mojo::Base '-base';
use Mojo::UserAgent;
use Data::Dumper;

has 'app' => undef;

sub get_type {
    my $self = shift;
    my $tm   = {
        'lightTank'     =>  'L',
        'mediumTank'    =>  'M',
        'heavyTank'     =>  'H',
        'AT-SPG'        =>  'T',
        'SPG'           =>  'S',
    };

    return $tm->{shift};
}

sub run {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new;

    if(my $tx = $ua->post('https://api.statterbox.com/wot/encyclopedia/tanks/' => form => { cluster => 'asia', language => 'en', application_id => $self->app->config->{statterbox}->{server} })) {
        if(my $res = $tx->success) {
            foreach my $typecomp (keys(%{$res->json->{data}})) {
                my $vdata = $res->json->{data}->{$typecomp};
                my $vname  = $vdata->{name};
                my ($dummy, $ident) = split(/:/, $vname, 2);
                my $doc   = { 
                    _id         => sprintf('%s:%s', $vdata->{nation}, $ident),
                    level       => $vdata->{level} + 0,
                    name        => $ident,
                    name_lc     => lc($ident),
                    country     => $vdata->{nation},
                    typecomp    => $typecomp + 0,
                    i18n        => $vdata->{name},
                    type        => $self->get_type($vdata->{type}),
                };
                $self->app->get_database->collection('data.vehicles')->save($doc);
                $self->app->log->debug('Update::Tanks: updated ' . $vdata->{name});
            }
        } else {
            $self->app->log->error('Update::Tanks: could not fetch update from encyclopedia: ' . Dumper($tx->error));
        }
    }
}

1;

