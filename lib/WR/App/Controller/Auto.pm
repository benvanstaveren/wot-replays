package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    $self->stash('timing.start' => [ Time::HiRes::gettimeofday ]);
    if(my $notify = $self->session->{'notify'}) {
        delete($self->session->{'notify'});
        $self->stash(notify => $notify);
    }

    my $req_host;
    if(my $url = $self->req->url->base) {
        if($url =~ /.*:\/\/(.*?)\.wot-replays\.org/) {
            $req_host = $1;
        }
    }
    $self->stash(req_host => $req_host || 'www');

    # this really should be happening nonblocking, is it possible to fire it up, pass it by in the return value,
    # and stick the data in the stash if needed? 
    #
    # perhaps...

    # twiddle peoples' openID username and password
    if($self->is_user_authenticated) {
        my $o = $self->session('openid');
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            my $server = $1;
            my $pname = $3;

            $server = 'sea' if(lc($server) eq 'asia'); # fuck WG and renaming endpoints

            $self->stash('current_player_name' => $pname);
            $self->stash('current_player_server' => uc($server));
            $self->stash('_current_user' => {
                name   => $pname,
                server => $server,
            });

            # needs to be updated 
            #$self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, {
            #    '$set' => {
            #        player_name     => $pname,
            #        player_server   => $server,
            #    }
            #});
        }
    }

    return 1;
}

1;
