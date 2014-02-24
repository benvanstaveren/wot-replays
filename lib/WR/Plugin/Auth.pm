package WR::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin';
use Try::Tiny qw/try catch/;
use Data::Dumper;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->helper('is_user_authenticated' => sub {
        my $self = shift;
        return (defined($self->stash('current_user')) && defined($self->session('openid'))) ? 1 : 0;
    });

    $app->helper(user => sub { return shift->current_user });
    $app->helper(current_user => sub {
        my $self = shift;
        return ($self->is_user_authenticated) ? $self->stash('current_user') : {}
    });

    $app->helper(update_current_user => sub {
        my $self = shift;
        my $set  = shift;
        my $cb   = shift;

        try {
            $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, { '$set' => $set } => $cb);
        } catch {
            $self->app->log->error('update_current_user exception: ' . $_ . ' for user: ' . Dumper($self->current_user));
        };
    });

    $app->helper(is_own_replay => sub {
        my $self = shift;
        my $r = shift;
	
        if($self->is_user_authenticated && ( ($self->current_user->{player_name} eq $r->{game}->{recorder}->{name}) && (lc($self->current_user->{player_server}) eq lc($r->{game}->{server})))) {
            return 1;
        } else {
            return 0;
        }
    });

    $app->helper(is_the_boss => sub {
        my $self = shift;
        if($self->is_user_authenticated && ( ($self->current_user->{player_name} eq 'Scrambled') && ($self->current_user->{player_server} eq 'sea'))) {
            return 1;
        } else {
            return 0;
        }
    });
    
    $app->helper(init_auth => sub {
        my $self   = shift; # controller object
        $self->render_later;
        if(my $o = $self->session('openid')) {
            $self->debug('have openid: ', $o);

            if($self->req->is_xhr) {
                $self->model('wot-replays.accounts')->find_one({ _id => $o } => sub {
                    my ($coll, $err, $user) = (@_);
                    if($user->{expires_at} > Mango::BSON::bson_time) {
                        $self->stash(current_user => $user);
                        $self->stash(current_player_name => $user->{player_name});
                        $self->stash(current_player_server => uc($user->{player_server}));
                    }
                    $self->continue;
                });
            } else {
                my $last_seen = Mango::BSON::bson_time;

                $self->model('wot-replays.accounts')->update({ 
                    _id => $o 
                }, {
                    '$set' => {
                        last_seen       => $last_seen,
                    },
                } => sub {
                    my ($coll, $err, $oid) = (@_);
                    $self->debug('last seen updated');
                    $self->model('wot-replays.accounts')->find_one({ _id => $o } => sub {
                        my ($coll, $err, $user) = (@_);

                        $self->debug('we have that account, yeah: ', Dumper($user));

                        $self->debug('expires_at: ', $user->{expires_at}, ' now: ', Mango::BSON::bson_time);

                        if(defined($user->{expires_at}) && $user->{expires_at} > Mango::BSON::bson_time) {
                            # later, we may just auth/prolongate this by a week if the expiry time is less than 86400 seconds away

                            $self->stash(current_user           => $user);
                            $self->stash(current_player_name    => $user->{player_name});
                            $self->stash(current_player_server  => uc($user->{player_server}));

                            $self->current_user->{last_clan_check} ||= 0;

                            $self->debug('expiry is okay');

                            if($self->current_user->{last_clan_check} < Mango::BSON::bson_time( (time() - 86400) * 1000)) {
                                my $url = 'http://api.statterbox.com/wot/account/clan';
                                my $server = lc($self->current_user->{player_server});
                                my $name   = $self->current_user->{player_name};

                                $server = 'asia' if($server eq 'sea');

                                # lookups by name are expensive, but hey... caching 4tw
                                my $form = {
                                    application_id => $self->stash('config')->{statterbox}->{server},
                                    name           => lc($name),
                                    cluster        => $server,
                                    fields         => 'abbreviation,name,emblems'
                                };
                                $self->ua->post($url => form => $form, sub {
                                    my ($ua, $tx) = (@_);

                                    my $clan;
                                    
                                    if(my $res = $tx->success) {
                                        if($res->json('/status') eq 'ok') {
                                            $clan = $res->json->{data}->{lc($self->current_user->{player_name})};
                                        } else {
                                            $clan = undef;
                                        }
                                    } else {
                                        $clan = undef;
                                    }
                                    $self->current_user->{clan} = $clan;
                                    $self->model('wot-replays.accounts')->update({ _id => $o }, { '$set' => {
                                        'last_clan_check' => Mango::BSON::bson_time,
                                        'clan'            => $clan,
                                    }} => sub {
                                        $self->continue;
                                    });
                                });
                            } else {
                                $self->continue;
                            }
                        } else {
                            $self->debug('auth is expired');
                            $self->session('openid' => undef, notify => { type => 'info', text => 'Your login has expired, you will have to log in again' });
                            $self->continue;
                        }
                    });
                });
            }
        } else {
            return 1;
        }
        return undef;
    });

    $app->helper('current_user_clan' => sub {
        my $self = shift;

        if($self->is_user_authenticated) {
            if(my $clan = $self->current_user->{clan}) {
                return $clan->{abbreviation};
            }
        }
        return undef;
    });

    $app->helper('has_admin_access' => sub {
        my $self = shift;

        return 1 if($self->is_the_boss);

        foreach my $clan (@{$self->stash('config')->{admin}->{clans}}) {
            if(defined($self->current_user->{clan})) {
                return 1 if($clan eq $self->current_user->{clan}->{abbreviation});
            }
        }
        return 1 if($self->has_role('admin'));
        return 0;
    });

    $app->helper('has_admin_role' => sub {
        my $self = shift;
        my $role = shift;
        my $roles_by_clan = {
            'WG' => [ 'events', 'moderator' ],
            'WGNA' => [ 'events', 'moderator' ],
        };

        return 1 if($self->is_the_boss);

        my $roles = $self->current_user->{roles} || [];
        my $other = (defined($self->current_user_clan)) ? $roles_by_clan->{$self->current_user_clan} || [] : [];

        foreach my $r (@$other) {
            push(@$roles, $r);
        }

        foreach my $r (@$roles) {
            return 1 if($r eq $role);
        }
        return 0;
    });
}        

1;
