package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    $self->stash('timing.start' => [ Time::HiRes::gettimeofday ]);

    my $last_seen = $self->session('last_seen') || 0;

    $self->session('last_seen' => time());
    $self->session('first_visit' => 1) if($last_seen + 86400 < time());
    $self->stash('hint_signin' => 1) unless(defined($self->session('gotit_signin')) && $self->session('gotit_signin') > 0);

    if(my $notify = $self->session->{'notify'}) {
        delete($self->session->{'notify'});
        $self->stash(notify => $notify);
    }

    $self->stash(
        settings => {
            first_visit => $self->session('first_visit'),
        },
    );

    if(my $host = $self->req->url->host) {
        if($host =~ /(www|na|sea|ru|vn|kr|eu)\.wot-replays\.org/) {
            $self->stash(req_host => $1);
            $self->stash(req_full => $host);
        }
    } else {
        $self->stash(req_host => 'www');
        $self->stash(req_full => 'unknown');
    }

    if(my $url = $self->req->url->base) {
        if($url =~ /http.*?:\/\/(.*?)\//) {
            my $host = $1;
            my @parts = reverse(split(/\./, $host));
            my $d = $parts[2];
            $self->stash('req_host' => $d);
        } else {
            $self->stash('req_host' => 'www');
        }
    } else {
        $self->stash('req_host' => 'www');
    }

    $self->app->log->info('url: ' . $self->req->url);

    # twiddle peoples' openID username and password
    if($self->is_user_authenticated) {
        my $o = $self->current_user->{openid};
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            my $server = $1;
            my $pname = $3;
            $self->stash('current_player_name' => $pname);
            $self->stash('current_player_server' => uc($server));

            # needs to be updated 
            $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, {
                '$set' => {
                    player_name     => $pname,
                    player_server   => $server,
                }
            });
        }
    }

    return 1;
}

1;


