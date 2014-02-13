package WR::Statterpush::Server;
use Mojo::Base '-base';
use Mojo::UserAgent;

has 'ua'        => sub { Mojo::UserAgent->new };
has 'token'     => undef;
has 'group'     => undef;

sub send_to_channel {
    my $self    = shift;
    my $channel = shift;
    my $message = shift;
    my $cb      = shift;

    warn 'send_to_channel: ', $channel, ' message: ', $message, "\n";

    if(!defined($cb)) {
        return $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/send_to_channel', $self->token, $self->group) => form => { channel => $channel, message => $message });
    }

    $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/send_to_channel', $self->token, $self->group) => form => {
        channel => $channel,
        message => $message
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $cb->($self, $res->json);
        } else {
            $cb->($self, undef);
        }
    });

}

sub channel_list {
    my $self    = shift;
    my $channel = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/channel_list', $self->token, $self->group) => form => {
        channel => $channel,
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $cb->($self, $res->json);
        } else {
            $cb->($self, undef);
        }
    });
}

sub user_present {
    my $self    = shift;
    my $user    = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/user_present', $self->token, $self->group) => form => {
        user => $user,
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $cb->($self, $res->json);
        } else {
            $cb->($self, undef);
        }
    });
}

sub user_count {
    my $self    = shift;
    my $channel = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/user_count', $self->token, $self->group) => form => {
        channel => $channel,
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $cb->($self, $res->json);
        } else {
            $cb->($self, undef);
        }
    });
}

sub send_to_user {
    my $self    = shift;
    my $user    = shift;
    my $message = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://api.statterbox.com/push/%s/%s/send_to_user', $self->token, $self->group) => form => {
        user    => $user,
        message => $message
    } => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $cb->($self, $res->json);
        } else {
            $cb->($self, undef);
        }
    });
}

1;
