package WR::Thunderpush::Server;
use Mojo::Base '-base';
use Mojo::UserAgent;

has 'ua'        => sub { Mojo::UserAgent->new };
has 'host'      => undef;
has 'key'       => undef;
has 'secret'    => undef;

sub _json {
    my $self = shift;
    my $tx   = shift;

    if(my $res = $tx->success) {
        return $res->json;
    } else {
        warn ref($self), ': _json: res not success, code: ', $tx->res->code, ' ', $tx->res->message, "\n";
        return undef;
    }
}

sub send_to_channel {
    my $self    = shift;
    my $channel = shift;
    my $message = shift;
    my $cb      = shift;

    if(defined($cb)) {
        $self->ua->post(sprintf('http://%s/api/1.0.0/%s/channels/%s/', 
            $self->host,
            $self->key,
            $channel
            ) => { 'X-Thunder-Secret-Key' => $self->secret } => json => $message => sub {
                my ($ua, $tx) = (@_);

                if(my $res = $tx->success) {
                    if(defined($res->json->{status})) {
                        return $cb->($self, $res->json);
                    } else {
                        return $cb->($self, { status => 200, response => $res->json });
                    }
                } else {
                    return $cb->($self, { status => 500, error => 'Request failed' });
                }
            });
    } else {
        return $self->_json($self->ua->post(sprintf('http://%s/api/1.0.0/%s/channels/%s/', $self->host, $self->key, $channel) => { 'X-Thunder-Secret-Key' => $self->secret } => json => $message));
    }
}

sub channel_list {
    my $self    = shift;
    my $channel = shift;
    my $cb      = shift;

    if(defined($cb)) {
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
    } else {
        return $self->_json($self->ua->get(sprintf('http://%s/api/1.0.0/%s/channels/%s/', $self->host, $self->key, $channel) => { 'X-Thunder-Secret-Key' => $self->secret }));
    }
}

sub user_present {
    my $self    = shift;
    my $user    = shift;
    my $cb      = shift;

    if(defined($cb)) {
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
    } else {
        return $self->_json($self->ua->get(sprintf('http://%s/api/1.0.0/%s/users/%s/', $self->host, $self->key, $user) => { 'X-Thunder-Secret-Key' => $self->secret }));
    }
}

sub user_count {
    my $self    = shift;
    my $cb      = shift;

    if(defined($cb)) { 
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
    } else {
        return $self->_json($self->ua->get(sprintf('http://%s/api/1.0.0/%s/users/', $self->host, $self->key,) => { 'X-Thunder-Secret-Key' => $self->secret }));
    }
}

sub send_to_user {
    my $self    = shift;
    my $user    = shift;
    my $message = shift;
    my $cb      = shift;

    if(defined($cb)) {
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
    } else {
        return $self->_json($self->ua->post(sprintf('http://%s/api/1.0.0/%s/users/%s/', $self->host, $self->key, $user) => { 'X-Thunder-Secret-Key' => $self->secret } => json => $message));
    }
}

1;
