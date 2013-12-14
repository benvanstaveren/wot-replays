package WR::OpenID::Response;
use Mojo::Base '-base';

has '_body'     => undef;
has 'params'    => sub {
    my $self    = shift;
    my $reply   = $self->_body;
    my %ret;

    $reply =~ s/\r//g;
    foreach (split /\n/, $reply) {
        next unless /^(\S+?):(.*)/;
        $ret{$1} = $2;
    }
    return \%ret;
};

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new();

    bless($self, $package);
    $self->_body(shift);
    return $self;
}

1;
