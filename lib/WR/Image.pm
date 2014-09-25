package WR::Image;
use Mojo::Base 'Mojolicious';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mango;
use WR::Util::QuickDB qw//;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wr.conf' });
    
    $self->plugin('WR::Plugin::Fixlog' => {});

    $self->secrets([ $config->{app}->{secret} ]); # same secret as main app? why not

    $self->attr(mango => sub { Mango->new($config->{mongodb}->{host}) });
    $self->helper(get_database => sub {
        my $s = shift;
        my $d = $config->{mongodb}->{database};
        return $s->app->mango->db($d);
    });
    $self->helper(model => sub {
        my $s = shift;
        my ($d, $c) = split(/\./, shift, 2);

        unless(defined($c)) {
            $c = $d ;
            $d = $config->{mongodb}->{database};
        } elsif(defined($d)) {
            $d = $config->{mongodb}->{database} if($d eq 'wot-replays'); # hack to make sure we pick up new db name if needed
        }
        return $s->app->mango->db($d)->collection($c);
    });

    my $preload = [ 'vehicles' ];
    foreach my $type (@$preload) {
        my $aname = sprintf('data_%s', $type);
        $self->attr($aname => sub {
            my $self = shift;
            return WR::Util::QuickDB->new(data => $self->mango->db('wot-replays')->collection(sprintf('data.%s', $type))->find()->all());
        });
        $self->helper($aname => sub {
            return shift->app->$aname();
        });
        $self->$aname();
    }

    $self->routes->namespaces([qw/WR::Image/]);
    my $root = $self->routes;

    my $vehicles = $root->under('/vehicles');
        $vehicles->route('/:size/:vehicle_string')->to('vehicles#index');
}

1;
