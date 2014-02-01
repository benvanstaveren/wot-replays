package WR::Thunderpush;
use Mojo::Base '-base';
use Mojo::UserAgent;

has 'ua'        => sub { Mojo::UserAgent->new };
has 'host'      => undef;
has 'key'       => undef;
has 'secret'    => undef;

sub send_to_channel {
    my $self    = shift;
    my $channel = shift;
    my $message = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://%s/api/1.0.0/%s/channels/%s/', 
        $self->host,
        $self->key,
        $channel
        ) => { 'X-Thunder-Secret-Key' => $self->secret } => json => $message => sub {
            my ($ua, $tx) = (@_);

            if(my $res = $tx->success) {
                if(defined($res->json->{status})) {
                    $cb->($self, $res->json);
                } else {
                    $cb->($self, { status => 200, response => $res->json });
                }
            } else {
                $cb->($self, { status => 500, error => 'Request failed' });
            }
        });
}

sub channel_list {
    my $self    = shift;
    my $channel = shift;
    my $cb      = shift;

    $self->ua->get(sprintf('http://%s/api/1.0.0/%s/channels/%s/', 
        $self->host,
        $self->key,
        $channel
        ) => { 'X-Thunder-Secret-Key' => $self->secret } => sub {
            my ($ua, $tx) = (@_);

            if(my $res = $tx->success) {
                if(defined($res->json->{status})) {
                    $cb->($self, $res->json);
                } else {
                    $cb->($self, { status => 200, response => $res->json });
                }
            } else {
                $cb->($self, { status => 500, error => 'Request failed' });
            }
        });
}

sub user_present {
    my $self    = shift;
    my $user    = shift;
    my $cb      = shift;

    $self->ua->get(sprintf('http://%s/api/1.0.0/%s/users/%s/', 
        $self->host,
        $self->key,
        $user
        ) => { 'X-Thunder-Secret-Key' => $self->secret } => sub {
            my ($ua, $tx) = (@_);

            if(my $res = $tx->success) {
                if(defined($res->json->{status})) {
                    $cb->($self, $res->json);
                } else {
                    $cb->($self, { status => 200, response => $res->json });
                }
            } else {
                $cb->($self, { status => 500, error => 'Request failed' });
            }
        });
}

sub user_count {
    my $self    = shift;
    my $cb      = shift;

    $self->ua->get(sprintf('http://%s/api/1.0.0/%s/users/', 
        $self->host,
        $self->key,
        ) => { 'X-Thunder-Secret-Key' => $self->secret } => sub {
            my ($ua, $tx) = (@_);

            if(my $res = $tx->success) {
                if(defined($res->json->{status})) {
                    $cb->($self, $res->json);
                } else {
                    $cb->($self, { status => 200, response => $res->json });
                }
            } else {
                $cb->($self, { status => 500, error => 'Request failed' });
            }
        });
}

sub send_to_user {
    my $self    = shift;
    my $user    = shift;
    my $message = shift;
    my $cb      = shift;

    $self->ua->post(sprintf('http://%s/api/1.0.0/%s/users/%s/', 
        $self->host,
        $self->key,
        $user
        ) => { 'X-Thunder-Secret-Key' => $self->secret } => json => $message => sub {
            my ($ua, $tx) = (@_);

            if(my $res = $tx->success) {
                if(defined($res->json->{status})) {
                    $cb->($self, $res->json);
                } else {
                    $cb->($self, { status => 200, response => $res->json });
                }
            } else {
                $cb->($self, { status => 500, error => 'Request failed' });
            }
        });
}

1;
