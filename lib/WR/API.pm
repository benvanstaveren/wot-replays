package WR::API;
use Mojo::Base 'Mojolicious';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mango;
use Mojo::Util qw/monkey_patch/;
use Scalar::Util qw/blessed/;
use WR;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wrapi.conf' });

    $self->secrets([ $config->{app}->{secret} ]); # same secret as main app? why not
    $self->defaults(config => $config);

    # set up the mango stuff here
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

    $self->routes->namespaces([qw/WR::API/]);

    my $root = $r->bridge('/')->to('auto#index');
        my $v1 = $root->under('/v1');
            my $data = $v1->under('/data');
                for(qw/equipment consumables vehicles components/) {
                    $data->route(sprintf('/%s', $_))->to('v1#validate_token', type => $_, next => 'data');
                }
            my $process = $v1->under('/process');
                $process->route('/')->to('v1#validate_token', next => 'process_replay');
                $process->route('/status/:job_id')->to('v1#validate_token', next => 'process_status');
            $v1->route('/typecomp')->to('v1#validate_token', next => 'resolve_typecomp');
            
            my $map = $v1->under('/map/:map_ident');
                $map->route('/')->to('v1#validate_token', next => 'map_details');
                my $heatmap = $map->under('/heatmap/:heatmap_type/:game_type');
                    $heatmap->route('/')->to('v1#validate_token', next => 'map_heatmap_data', bonus_types => '0,1,2,3,4,5,6,7');
                    $heatmap->route('/:bonus_types')->to('v1#validate_token', next => 'map_heatmap_data');


}

1;
