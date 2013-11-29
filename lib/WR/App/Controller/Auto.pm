package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    $self->stash('timing.start' => [ Time::HiRes::gettimeofday ]);
    if(my $notify = $self->session->{'notify'}) {
        delete($self->session->{'notify'});
        $self->stash(notify => $notify);
    }

    if($self->is_user_authenticated) {
        my $o = $self->session('openid');
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            my $server = $1;
            my $pname = $3;

            $server = 'sea' if(lc($server) eq 'asia'); # fuck WG and renaming endpoints

            $self->stash('current_player_name' => $pname);
            $self->stash('current_player_server' => uc($server));
            $self->stash('current_user' => {
                player_name   => $pname,
                player_server => $server,
            });
        }
    }

    return 1;
}

1;
