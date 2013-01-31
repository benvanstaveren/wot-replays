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

    # find out what mode we're operating in, based on this we need to do some juju with the template paths
    
    my $url = $self->req->url->base;
    my $host;

    if($url =~ /http.*?:\/\/(.*?)(:\d+)*\//) {
        $host = $1;
    } else {
        $host = undef;
    }

    my $opmode = 'default';

    if(!defined($host) || $host eq 'localhost') {
        $opmode = $self->stash('config')->{dev}->{opmode} || 'default';
        $self->stash(page_owner => $self->stash('config')->{dev}->{page_owner});
        $self->stash(page_owner_server => $self->stash('config')->{dev}->{page_owner_server});
    } else {
        my @hostparts = reverse(split(/\./, $host));
        # org.wot-replays.<x>.<y>
        if($hostparts[2] eq 'www') {
            $opmode = 'default';
        } elsif($hostparts[2] =~ /^(sea|ru|na|eu|vn)$/) {
            $opmode = 'personal';
            $self->stash('page_owner' => $hostparts[3]);
            $self->stash('page_owner_server' => $hostparts[2]);
        } else {
            # figure it's a clan page
            $opmode = 'clan';
            $self->stash('page_owner' => $hostparts[2]);
        }
    }

    $self->stash(opmode => $opmode);

    return 1;
}

1;


