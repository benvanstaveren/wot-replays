package WR::Web::API;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojo::Base 'Mojolicious';
use WR;

sub startup {
    my $self = shift;
    my $r    = $self->routes;

    my $config = $self->plugin('Config', { file => 'wr-api.conf' });

    $self->secrets([ $config->{app}->{secret} ]); # same secret as main app? why not
    $self->defaults(config => $config);

    $self->plugin('WR::Plugin::Mango' => $config->{mongodb});

    $self->routes->namespaces([qw/WR::Web::API/]);

    my $v1 = $r->under('/v1');
        my $process = $v1->under('/process');
            $process->route('/upload')->to('v1#validate_token', next => 'process_replay');
            $process->route('/status/:job_id')->to('v1#validate_token', next => 'process_status');

    my $util = $r->under('/util');
        $util->route('/battleresult/submit')->to('util#battleresult_submit');
    


}

1;
