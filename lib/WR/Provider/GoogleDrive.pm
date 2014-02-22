package WR::Provider::GoogleDrive;
use Mojo::Base '-base';
use Crypt::Blowfish;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::JSON;

# app tokens
has 'client_id'         =>  undef;
has 'client_secret'     =>  undef;
has 'blowfish_key'      =>  undef;

# user account_id
has 'account_id'        =>  undef;

# details...
has 'ua'                =>  undef;
has 'coll'              =>  undef; # access and refresh token storage, kept in an encrypted state 

has 'blowfish'          => sub {
    my $self = shift;
    return Crypt::Blowfish->new($self->blowfish_key);
};

sub encrypt {
    my $self = shift;
    my $text = shift;

    # pad with 0x00 if we're not up to an 8 byte boundary
    if(my $missing = (length($text) % 8)) {
        $text .= "\x00" x $missing;
    }
    return $self->blowfish->encrypt($text);
}

sub decrypt {
    my $self = shift;
    my $text = shift;

    # pad with 0x00 if we're not up to an 8 byte boundary
    if(my $missing = (length($text) % 8)) {
        $text .= "\x00" x $missing;
    }
    return $self->blowfish->decrypt($text);
}

sub has_access_token {
    my $self = shift;
    my $cb   = shift;

    $self->coll->find_one({ _id => $self->account_id } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($err)) {
            return $cb->($self, $err, undef);
        } elsif(!defined($doc)) {
            return $cb->($self, undef, undef);
        } else {
            return $cb->($self, undef, $doc);
        }
    });
}

sub authorize_url {
    my $self        = shift;
    my $redirect_to = shift;
    my $url         = Mojo::URL->new('https://accounts.google.com/o/oauth2/auth');

    $url->query(
        response_type   => 'code',
        client_id       =>  $self->client_id,
        redirect_uri    =>  $redirect_to,
        scope           =>  'https://www.googleapis.com/auth/drive.readonly',
    );
    return $url;
}

1;
