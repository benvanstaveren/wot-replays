package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;

sub root_bridge {
    my $self = shift;

    $self->debug('top');

    if(my $o = $self->session('openid')) {
        $self->debug('have openid: ', $o);
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            $self->debug('openid matches regex');
            my $server = $1;
            my $pname = $3;

            $server = 'sea' if(lc($server) eq 'asia'); # fuck WG and renaming endpoints

            my $user_id   = sprintf('%s-%s', lc($server), lc($pname));

            if($self->req->is_xhr) {
                $self->debug('request is XHR, loading user');
                $self->model('wot-replays.accounts')->find_one({ _id => $user_id } => sub {
                    my ($coll, $err, $user) = (@_);
                    $self->stash(current_user => $user);
                    $self->stash(current_player_name => $user->{player_name});
                    $self->stash(current_player_server => uc($user->{player_server}));
                    $self->debug('user loaded, continue');
                    $self->continue;
                });
                $self->debug('post-load');
                return 1;
            } else {
                $self->debug('request is not XHR');
                my $last_seen = Mango::BSON::bson_time;

                $self->debug('updating user with last seen');
                $self->model('wot-replays.accounts')->update({ 
                    _id => $user_id 
                }, {
                    '$set' => {
                        player_name     => $pname,
                        player_server   => lc($server),
                        last_seen       => $last_seen,
                    },
                }, {
                    upsert => 1,
                },
                sub {
                    my ($coll, $err, $oid) = (@_);
                    $self->debug('user updated');
                    $self->debug('loading user');
                    $self->model('wot-replays.accounts')->find_one({ _id => $user_id } => sub {
                        my ($coll, $err, $user) = (@_);

                        $self->debug('user loaded');

                        $self->stash(current_user           => $user);
                        $self->stash(current_player_name    => $user->{player_name});
                        $self->stash(current_player_server  => uc($user->{player_server}));

                        $self->current_user->{last_clan_check} ||= 0;

                        if($self->current_user->{last_clan_check} < Mango::BSON::bson_time( (time() - 86400) * 1000)) {
                            $self->debug('clan check needed');
                            # we need to re-check the users' clan settings, we do that by yoinking statterbox for it
                            my $url = sprintf('http://statterbox.com/api/v1/%s/clan?server=%s&player=%s', 
                                '5299a074907e1337e0010000', # yes it's a hardcoded API token :P
                                lc($self->current_user->{player_server}),
                                lc($self->current_user->{player_name}),
                                );
                            $self->debug('fetching from ', $url);
                            $self->ua->get($url => sub {
                                my ($ua, $tx) = (@_);
                                my $clan = undef;

                                $self->debug('url fetched');
                                
                                if(my $res = $tx->success) {
                                    if($res->json->{ok} == 1) {
                                        $self->debug('have clan data');
                                        $clan = $res->json->{data}->{lc($self->current_user->{player_name})};
                                    } else {
                                        $self->debug('no clan data');
                                        $clan = undef;
                                    }
                                } else {
                                    $self->debug('request failed');
                                    $clan = undef;
                                }
                                $self->current_user->{clan} = $clan;
                                $self->debug('updating user for clan');
                                $self->model('wot-replays.accounts')->update({ _id => $user_id }, { '$set' => {
                                    'last_clan_check' => Mango::BSON::bson_time,
                                    'clan'            => $clan,
                                }} => sub {
                                    $self->debug('clan check results saved, continue');
                                    $self->continue;
                                });
                            });
                        } else {
                            $self->debug('no clan check required, continue');
                            $self->continue;
                        }
                    });
                });
                $self->debug('post last-seen update');
                return undef;
            }
        } else {
            $self->debug('openid does not match regex');
            return 1;
        }
    } else {
        $self->debug('no openid in session');
        return 1;
    }
    $self->debug('************* bottom of root_bridge, should not reach here ***********************************');
}

1;
