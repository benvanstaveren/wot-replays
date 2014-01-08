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
}

1;

