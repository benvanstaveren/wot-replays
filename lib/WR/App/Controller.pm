package WR::App::Controller;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON;

sub auto {
    my $self = shift;
    my $next = $self->stash('next');

    $self->render_later;

    $self->auth_setup(sub {
        my $c = shift;
        my $user = shift;

        if(defined($user)) {
            $c->stash(current_user => $user);
            $c->stash(current_player_name => $user->{player_name});
            $c->stash(current_player_server => uc($user->{player_server}));

            $c->current_user->{last_clan_check} ||= 0;

            if($c->current_user->{last_clan_check} < Mango::BSON::bson_time( (time() - 86400) * 1000)) {
                # we need to re-check the users' clan settings, we do that by yoinking statterbox for it
                 my $url = sprintf('http://statterbox.com/api/v1/%s/clan?server=%s&player=%s', 
                        '5299a074907e1337e0010000', # yes it's a hardcoded API token :P
                        lc($c->current_user->{player_server}),
                        lc($c->current_user->{player_name}),
                        );
                $c->ua->get($url => sub {
                    my ($ua, $tx) = (@_);
                    my $clan = undef;
                    
                    if(my $res = $tx->success) {
                        if($res->json->{ok} == 1) {
                            $clan = $res->json->{data}->{lc($c->current_user->{player_name})};
                        } else {
                            $clan = undef;
                        }
                    } else {
                        $clan = undef;
                    }
                    $c->current_user->{clan} = $clan;
                    $c->update_current_user({
                        'last_clan_check' => Mango::BSON::bson_time,
                        'clan'            => $clan,
                    } => sub {
                        $c->$next;
                    });
                });
            } else {
                $c->$next;
            }
        } else {
            # user is not authenticated, if mustauth is set we should redirect to a login page
            if(defined($c->stash('mustauth')) && ($c->stash('mustauth') == 1)) {
                # we do want to call the setup end but with a redirect
                $c->redirect_to('/login');
            } else {
                $c->$next;
            }
        }
    });
}

sub respond {
    my $self = shift;
    my %args = (@_);
    my $stash = delete($args{'stash'});

    $self->stash(%$stash) if(defined($stash));
    if(my $start = $self->stash('timing.start')) {
        $self->stash('timing_elapsed' => Time::HiRes::tv_interval($start));
    }
    $self->render(%args);
}

1;
