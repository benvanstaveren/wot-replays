package WR::Parser::Stream;
use Mojo::Base 'Mojo::EventEmitter';
use WR::Parser::Stream::Packet;
use WR::Util::VehicleDescriptor;
use Module::Find qw/usesub/;
use Try::Tiny qw/try catch/;
use Time::HiRes qw//;

# this thing actually is a very low level packet streamer that does no emitting of it's own beyond emitting packets, and a finish event

has 'fh'           => undef;      # IO::String object actually, not a filehandle, contains the unpacked replay
has 'pos'          => 0;
has 'len'          => sub { length(${shift->fh->string_ref}) };
has 'stopping'     => 0;
has 'modules'      => sub { {} };

$| = 1;

use constant END_OF_STREAM => 0xffffffff;

sub stop { shift->stopping(1) }
sub cancel { shift->stopping(1) }

sub safe_unpickle {
    my $self = shift;
    my $pd   = shift;
    my $res  = undef;

    try {
        $res = WR::Util::PyPickle->new(data => $pd)->unpickle;
    } catch {
        $res = undef;
    };

    return $res;
}

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);
    
    bless($self, $package);

    foreach my $packetmodule (usesub('WR::Parser::Stream::Packet')) {
        my $name = $packetmodule;
        $self->modules->{$name}++;
    }

    $self->fh->seek(0, 0);
    return $self;
}

sub safe_read {
    my $self = shift;
    my $size = shift;
    my $u    = shift;

    if(my $bread = $self->fh->read(my $buffer, $size)) {
        $buffer = unpack($u, $buffer) if(defined($u));
        return ($bread == $size) ? $buffer : undef;
    } else {
        warn '[safe_read]: wanted to read ', $size, ' bytes, but only got ', $bread, "\n";
    }
    return undef;
}

sub has_next {
    my $self = shift;
    return ($self->fh->tell < $self->len) ? 1 : 0;
}

sub position {
    my $self = shift;
    my $p = $self->fh->tell;
    return $self->len if($p > $self->len);
    return $p;
}

sub _finish {
    my $self = shift;
    my $reason = shift;
    my $p = shift;

    $self->emit(finish => $reason);
    $self->stop;
    return (defined($p)) ? $p : undef;
}

sub next {
    my $self = shift;

    return undef if($self->stopping);

    my $payload_s = $self->safe_read(4, 'L');
    my $pt        = $self->safe_read(4, 'L');
    my $pm        = sprintf('WR::Parser::Stream::Packet::0x%02x', $pt);

    return $self->_finish({ ok => 0, reason => sprintf('EOF PT: %02x (%d), PS: %d', $pt, $pt, $payload_s) }) unless(defined($payload_s) && defined($pt)); # not really true but...
    return $self->_finish({ ok => 0, reason => sprintf('NOSUCHPACKET: %02x (%d), module %s', $pt, $pt, $pm) }) unless(defined($self->modules->{$pm}));

    my $pb = IO::String->new;
    $pb->binmode(1);

    return $self->_finish({ ok => 0, reason =>  'PACKETBEYONDBUFFER' }) if($self->fh->tell + $payload_s > $self->len);

    # rewind by 8 bytes
    $self->fh->seek(-8, 1);

    my $ps = $self->fh->tell;

    $self->fh->read(my $packet_data, 12 + $payload_s);
    my $o = undef;
    try {
        $o = $pm->new(data => $packet_data, packet_offset => $ps, packet_size => 12 + $payload_s);
    } catch {
        $self->_finish({ ok => 0, reason => $_ });
        $o = undef;
    };
    if($pt == $self->END_OF_STREAM) {
        return $self->_finish({ ok => 1, reason => 'end of stream' }, $o);
    } else {
        return $o;
    }
}

1;
