package WR::App::Controller::Postaction;
use Mojo::Base 'WR::App::Controller';

sub nginx_post_action {
    my $self = shift;
    my $file = $self->req->param('f');
    my $stat = $self->req->param('s');
    my $ip   = $self->req->param('i');

    $self->render_later;
    if(defined($stat) && lc($stat) eq 'ok') {
        my $real_file = substr($file, 1); # because we want to ditch that leading slash
        if($real_file =~ /^(mods|patches)/) {
            $self->render(text => 'OK');
        } else {
            $self->model('replays')->find_and_modify({ 
                query   =>  { file => $real_file },
                update  =>  { '$inc' => { 'site.downloads' => 1 } },
            } => sub {
                my ($c, $e, $d) = (@_);

                if(defined($d)) {
                    $self->_piwik_track_download($file => $ip => sub {
                        $self->app->thunderpush->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.download', data => { id => $d->{_id} . '' } }) => sub {
                            my ($p, $r) = (@_);
                            $self->render(text => 'OK');
                        });
                    });
                } else {
                    $self->render(text => 'OK');
                }
            });
        }
    } else {    
        $self->render(text => 'OK');
    }
}

sub _piwik_track_download {
    my $self = shift;
    my $file = shift;
    my $ip   = shift;
    my $cb   = shift;

    $self->ua->get($self->get_config('piwik.url') => form => {
        idsite          => 1,
        token_auth      => $self->get_config('piwik.token_auth'),
        rec             => 1,
        url             => sprintf('http://dl.wotreplays.org%s', $file),
        action_name     => 'Replay/Download',
        apiv            => 1,
        download        => sprintf('http://dl.wotreplays.org%s', $file),
        cip             => $ip, 
    } => $cb);
}

1;
