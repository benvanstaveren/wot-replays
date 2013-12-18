package WR::API;
use Mojo::Base 'Mojolicious';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mango;
use WR;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wrapi.conf' });

    $self->secret($config->{app}->{secret}); # same secret as main app? why not
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
            $v1->route('/typecomp')->to('v1#validate_token', next => 'resolve_typecomp');
            my $process = $v1->under('/process');
                $process->route('/')->to('v1#validate_token', next => 'process_replay');
                $process->route('/status/:job_id')->to('v1#process_status'); # yep no token required here...
            
            my $replay = $v1->under('/replay/:replay_id');
                $replay->route('packets')->to('v1#replay_packets'); # and no token here either...

}

1;
