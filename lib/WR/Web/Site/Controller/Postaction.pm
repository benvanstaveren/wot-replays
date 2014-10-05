package WR::Web::Site::Controller::Postaction;
use Mojo::Base 'WR::Web::Site::Controller';

sub preview {
    my $self = shift;
    my $file = $self->req->param('f');
    my $stat = $self->req->param('s');
    my $ip   = $self->req->param('i');

    $self->render_later;
    if(defined($stat) && lc($stat) eq 'ok') {
        my $real_file = substr($file, 1); # because we want to ditch that leading slash
        $self->_piwik_track_download($file => $ip => 'previews.wotreplays.org' => sub {
            $self->app->thunderpush->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.download', data => { id => $d->{_id} . '' } }) => sub {
                my ($p, $r) = (@_);
                $self->render(text => 'OK');
            });
        });
    } else {
        $self->render(text => 'OK');
    }
}

sub replay {
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
                    $self->_piwik_track_download($file => $ip => 'dl.wotreplays.org' => sub {
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
    my $host = shift;
    my $cb   = shift;

    $self->ua->get($self->get_config('piwik.url') => form => {
        idsite          => 1,
        token_auth      => $self->get_config('piwik.token_auth'),
        rec             => 1,
        url             => sprintf('http://%s%s', $host, $file),
        action_name     => ($host eq 'dl.wotreplays.org') ? 'Replay/Download' : 'Replay/Preview',
        apiv            => 1,
        download        => sprintf('http://%s%s', $host, $file),
        cip             => $ip, 
    } => $cb);
}

1;
