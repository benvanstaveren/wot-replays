package WR::Parser::Unpack;
use Mojo::Base '-base';
use Crypt::Blowfish;
use IO::String ();
use IO::File ();
use POSIX ();
use Try::Tiny qw/catch try/;
use IO::Uncompress::AnyUncompress qw/anyuncompress $AnyUncompressError/;

# we expect a filehandle to be passed that has already been opened, returns an open filehandle 
# for the unpacked replay; a file handle may be an IO::String object

has fh          => undef;
has bf_key      => undef;
has blowfish    => sub {
    my $self = shift;
    return Crypt::Blowfish->new($self->bf_key);
};

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    die 'Missing fh', "\n" unless(defined($self->fh));

    return $self;
}

sub unpack {
    my $self = shift;

    return $self->unpack_replay($self->decrypt_replay);
}

sub decrypt_replay {
    my $self = shift;

    my $decrypted = IO::String->new();
    $decrypted->binmode(1);

    my $bc   = 0;
    my $previous_block;

    $self->fh->seek(0, 0);
    while(my $bread = $self->fh->read(my $block, 8)) {
        if($bread < 8) {
            my $missing = 8 - $bread;
            $block .= chr(0) x $missing;
        }
        if($bc > 0) {
            my $decrypted_block = $self->blowfish->decrypt($block);
            $decrypted_block = $decrypted_block ^ $previous_block if($bc > 1);
            $previous_block = $decrypted_block;
            $decrypted->write($decrypted_block);
        }
        $bc++;
    }
    $decrypted->seek(0, 0);
    return $decrypted;
}

sub unpack_replay {
    my $self        = shift;
    my $decrypted   = shift;
    my $unpacked    = IO::String->new();

    $unpacked->binmode(1);

    anyuncompress($decrypted->string_ref => $unpacked->string_ref) or die '[unpack]: ', $AnyUncompressError, "\n";

    $unpacked->seek(0, 0);
    return $unpacked;
}

1;
