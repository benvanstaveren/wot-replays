package WR::Update::Components;
use Mojo::Base '-base';
use Mojo::UserAgent;
use Data::Dumper;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;

has 'app' => undef;

sub run {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new;

    foreach my $type (qw/engines turrets radios chassis guns/) {
        if(my $tx = $ua->post(sprintf('https://api.statterbox.com/wot/encyclopedia/tank%s/', $type) => form => { cluster => 'asia', language => 'en', application_id => $self->app->config->{statterbox}->{server} })) {
            if(my $res = $tx->success) {
                if($res->json->{status} eq 'ok') {
                    foreach my $component (values(%{$res->json->{data}})) {
                        my $typecomp = $component->{module_id};
                        my $compact = parse_int_compact_descr($typecomp + 0);
                        $compact->{type} = type_id_to_name($compact->{type_id});
                        my $doc = { 
                            _id             =>  $typecomp + 0,
                            country         =>  $component->{nation},
                            component_id    =>  $compact->{id} + 0,
                            i18n            =>  sprintf('#%s_vehicles:%s', $component->{nation}, $component->{name}),
                            component       =>  $type,
                        };
                        $self->app->get_database->collection('data.components')->save($doc);
                    }
                } else {
                    $self->app->log->error('Update::Components: could not fetch update for ' . $type . ' from encyclopedia: ' . $res->json->{error});
                }
            } else {
                $self->app->log->error('Update::Components: could not fetch update for ' . $type . ' from encyclopedia: ' . Dumper($tx->error));
            }
        }
        $self->app->log->debug('Update::Components: updated ' . $type);
    }
}

1;
