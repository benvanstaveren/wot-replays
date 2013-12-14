package WR::OpenID;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::UserAgent;
use WR::OpenID::Response;
use Digest::SHA qw(hmac_sha1_hex);
use Mojo::Util qw/url_escape url_unescape/;

has 'openid_endpoint'   =>  'id/openid/';
has 'ua'                =>  sub { Mojo::UserAgent->new };
has 'region'            =>  undef;
has 'schema'            =>  'https';
has 'nb'                =>  1;
has 'return_to'         =>  undef; 
has 'realm'             =>  'http://www.wotreplays.org';
has 'assoc_handle'      =>  undef;
has 'mac_key'           =>  undef;
has 'nonce_cache'       =>  undef;  # should be a mango collection

has 'openid_url'        => sub {
    my $self = shift;
    my $url  = sprintf('%s://%s.wargaming.net/%s', $self->schema, $self->region, $self->openid_endpoint);
    return $url;
};

sub response {
    my $self    = shift;
    my %args    = (@_);
    my $params  = $args{'params'};

    $self->emit('not_openid') and return unless(defined($params->{'openid.ns'}));
    $self->emit('setup_needed') and return if($params->{'openid.mode'} eq 'setup_needed');
    $self->emit('cancelled') and return if($params->{'openid.mode'} eq 'cancel');
    $self->emit('error' => $params->{'openid.error'}) and return if($params->{'openid.mode'} eq 'error');

    $self->emit('error' => 'Bad mode') and return unless($params->{'openid.mode'} eq 'id_res');

    # go for the verified identity thing
    my $a_ident = $params->{'openid.identity'};
    my $sig64   = $params->{'openid.sig'};
    $sig64 =~ s/ /+/g;

    my $return_to = $params->{'openid.return_to'};
    my $signed    = $params->{'openid.signed'};
    my $ident     = $params->{'openid.claimed_id'} || $a_ident;
    my $server    = $params->{'openid.op_endpoint'};

    $self->emit('error' => 'Wrong return URL') and return unless($params->{'openid.return_to'} eq $self->return_to);

    $self->nonce_cache->find_one({ _id => $params->{'openid.response_nonce'} } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($doc)) {
            $self->emit('error' => 'Duplicate nonce');
        } else {
            $self->nonce_cache->save({ _id => $params->{'openid.response_nonce'}, identity => $ident, created => Mango::BSON::bson_time } => sub {
                my ($coll, $err, $oid) = (@_);
                my $continue = 0;

                if(defined($params->{'openid.oic.time'})) {
                    my ($sig_time, $sig) = split(/\-/, $params->{'openid.oic.time'} || '');
                    if($sig_time < time() - 3600) {
                        $self->emit('error' => 'Request too old (', (time() - 3600) - $sig_time, ' seconds)');
                    } elsif($sig_time > time() + 30) {
                        $self->emit('error' => 'Request wants to time travel');
                    } else {
                        $continue = 1;
                    }
                } else {
                    $continue = 1;
                }

                if($continue == 1) {
                    # should now verify the identity but I have a case of the lazies and this isn't here yet so
                    if(defined($args{'skip_verify'}) && $args{'skip_verify'} > 0) {
                        $self->emit('verified' => $ident)
                    } else {
                        $self->emit('error' => 'Asked for verification but not implemented yet, someone bug Scrambled!');
                    }
                } 
            });
        }
    });
}

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);
    bless($self, $package);

    $self->ua->max_redirects(10);
    $self->ua->inactivity_timeout(10);
    return $self;
}

sub _url {
    my $self = shift;
    my $form = shift;

    $form->{'openid.ns'} = 'http://specs.openid.net/auth/2.0';

    my $u = Mojo::URL->new($self->openid_url);
    $u->query($form);
    return $u->to_string;
}


sub _request {
    my $self = shift;
    my $form = shift;
    my $cb   = shift;

    $form->{'openid.ns'} = 'http://specs.openid.net/auth/2.0';

    if($self->nb) {
        $self->ua->post($self->openid_url, { 'Accept-Encoding' => undef, 'Content-Type' => 'application/x-www-form-urlencoded' } => form => $form, sub {
            my ($ua, $tx) = (@_);

            if(defined($tx)) {
                if(my $res = $tx->success) {
                    $cb->($self, undef, WR::OpenID::Response->new($res->body));
                } else {
                    $cb->($self, $tx->error, undef);
                }
            } else {
                $cb->($self, 'no tx', undef);
            }
        });
    } else {
        if(my $tx = $self->ua->post($self->openid_url, { 'Content-Type' => 'application/x-www-form-urlencoded' } => form => $form)) {
            if(my $res = $tx->success) {
                $cb->($self, undef, WR::OpenID::Response->new($res->body));
            } else {
                $cb->($self, $tx->error, undef);
            }
        } else {
            $cb->($self, 'no tx', undef);
        }
    }
}

sub checkid_setup {
    my $self = shift;
    my $claimed_id = shift;
    my $cb         = shift;

    return $self->checkid($claimed_id, 'setup', $cb);
}

sub checkid_immediate {
    my $self = shift;
    my $claimed_id = shift;
    my $cb         = shift;

    return $self->checkid($claimed_id, 'immediate', $cb);
}

sub checkid {
    my $self        = shift;
    my $claimed_id  = shift;
    my $mode        = sprintf('checkid_%s', shift);
    my $cb          = shift;

    my $form = {
        'openid.mode'           =>  $mode,
        'openid.claimed_id'     =>  $claimed_id,
        'openid.identity'       =>  'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.return_to'      =>  $self->return_to,
        'openid.realm'          =>  $self->realm,
    };

    $form->{'openid.assoc_handle'} = $self->assoc_handle if(defined($self->assoc_handle));

    if(defined($cb)) {
        $self->_request($form, $cb);
        return undef;
    } else {
        return $self->_url($form);
    }
}

sub assoc {
    my $self = shift;
    my $cb   = shift;
    my $form = {
        'openid.mode'           =>  'associate',
        'openid.assoc_type'     =>  'HMAC-SHA1',
        'openid.session_type'   =>  'no-encryption',
    };

    $self->_request($form, $cb);
}

1;
