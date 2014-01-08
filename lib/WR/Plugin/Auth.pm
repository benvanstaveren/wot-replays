package WR::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin';
use Try::Tiny qw/try catch/;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->helper('auth_setup' => sub {
        my $self = shift;
        my $cb   = shift; # callback that is called once the setup is complete, is passed the controller object

        try {
            if(my $o = $self->session('openid')) {
                if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
                    my $server = $1;
                    my $pname = $3;

                    $server = 'sea' if(lc($server) eq 'asia'); # fuck WG and renaming endpoints

                    my $user_id   = sprintf('%s-%s', lc($server), lc($pname)),
                    my $last_seen = Mango::BSON::bson_time;

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
                        $app->log->debug('updated user');
                        $self->model('wot-replays.accounts')->find_one({ _id => $user_id } => sub {
                            my ($coll, $err, $user) = (@_);
                            $cb->($self, $user);
                        });
                    });
                } else {
                    $cb->($self, undef);
                }
            } else {
                $cb->($self, undef);
            }
        } catch {
            $self->app->log->error('auth_setup exception: ' . $_);
            $cb->($self, undef);
        };
    });

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

        $self->model('wot-replays.accounts')->update({ _id => $self->current_user->{_id} }, { '$set' => $set } => $cb);
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
}

1;

