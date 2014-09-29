package WR::Plugin::Preloader;
use Mojo::Base 'Mojolicious::Plugin';
use WR::Util::QuickDB;

sub register {
    my $self = shift;
    my $app  = shift;
    my $conf = shift;

    foreach my $type (@$conf) {
        $app->debug('[WR::Plugin::Preloader]: preloading: ',  $type);
        my $aname = sprintf('data_%s', $type);
        $app->attr($aname => sub {
            my $self = shift;
            return WR::Util::QuickDB->new(data => $self->get_database->collection(sprintf('data.%s', $type))->find()->all());
        });
        $app->helper($aname => sub {
            return shift->app->$aname();
        });
        $app->$aname();
    }
}

1;

