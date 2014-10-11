package WR::Parser::Stream;
use Mojo::Base 'Mojo::EventEmitter';
use Module::Find qw/findsubmod/;
use Try::Tiny qw/try catch/;
use Data::Dumper qw/Dumper/;
use Module::Load qw/load/;

has 'fh'           => undef;      # IO::String object actually, not a filehandle, contains the unpacked replay
has 'type'         => undef;      # the type of replay we're reading, it does matter... 
has 'pos'          => 0;
has 'len'          => sub { length(${shift->fh->string_ref}) };
has 'stopping'     => 0;
has 'modules'      => sub { [] };
has 'log'          => undef;
has 'version'      => undef;      # numeric version of the replay we're streaming

$| = 1;

use constant END_OF_STREAM => 0xffffffff;

sub stop    { shift->stopping(1) }
sub cancel  { shift->stopping(1) }
sub reset   { 
    my $self = shift;

    $self->fh->seek(0, 0);
    $self->pos(0);
}

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join('', '[WR::Parser::Stream]: ', @_);
    
    $self->log->$l($m) if(defined($self->log));
}

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub warning { shift->_log('warning', @_) }
sub fatal   { shift->_log('fatal', @_) }
sub error   { shift->_log('error', @_) }

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    $self->debug('Stream instantiation for ', $self->type);

    $self->debug('Loading default packet modules');
    foreach my $packetmodule (findsubmod(sprintf('WR::Parser::Stream::Packet::%s::default', uc($self->type)))) {
        my $name = $packetmodule;
        $name =~ s/.*://g; 
        $self->debug('- Found ', $packetmodule, ' as ', $name);
        # name is a hex number, we want to convert that to decimal
        try {
            load $packetmodule;
            $self->modules->[hex($name) + 0] = $packetmodule;
        } catch {
            $self->error($packetmodule, ' failed to load: ', $_);
        };
    }

    use Data::Dumper;
    $self->debug('Using default packet modules: ', Dumper($self->modules));

    if(defined($self->version)) {
        $self->debug('Loading version packet modules for ', $self->version);
        foreach my $packetmodule (findsubmod(sprintf('WR::Parser::Stream::Packet::%s::%s', uc($self->type), $self->version))) {
            my $name = $packetmodule;
            $name =~ s/.*://g; 
            $self->debug('- Found ', $packetmodule, ' as ', $name);
            # name is a hex number, we want to convert that to decimal
            try {
                load $packetmodule;
                $self->modules->[hex($name) + 0] = $packetmodule;
            } catch {
                $self->error($packetmodule, ' failed to load: ', $_);
            };
        }
    } else {
        $self->debug('No version? Okay, default it is...');
    }

    $self->debug('Using final packet modules: ', Dumper($self->modules));

    # cheesy
    $self->emit('stream.size' => $self->len);

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
    my $self    = shift;
    my $reason  = shift;
    my $p       = shift;

    $self->debug('_finish called, reason: ', Dumper($reason));
    $self->emit(finish => $reason);
    $self->stop;
    return (defined($p)) ? $p : undef;
}

sub next {
    my $self = shift;
    my $cb   = shift;

    return (defined($cb)) ? $cb->($self, $self->_next) : $self->_next;
}

sub scan {
    my $self = shift;
    my $pl   = shift;
    my $cb   = shift;
    my $tl   = { map { $_ => 1 } @$pl };

    while(my $packet = $self->_next) {
        next unless defined($tl->{$packet->type});
        last unless($cb->($self, $packet));
    }
    $self->reset();
}

sub _next {
    my $self = shift;

    return undef if($self->stopping);

    my $payload_s = $self->safe_read(4, 'L');
    my $pt        = $self->safe_read(4, 'L');

    return $self->_finish({ ok => 0, reason => sprintf('EOF PT: %02x (%d), PS: %d', $pt, $pt, $payload_s) }) unless(defined($payload_s) && defined($pt)); # not really true but...

    my $pm        = $self->modules->[$pt];

    return $self->_finish({ ok => 0, reason => sprintf('NOSUCHPACKET: %02x (%d), module %s', $pt, $pt, $pm) }) unless(defined($pm));

    # if PT == END_OF_STREAM we just return
    return $self->_finish({ ok => 1, reason => 'end of stream'}, undef) if($pt == $self->END_OF_STREAM);
    return $self->_finish({ ok => 0, reason =>  'PACKETBEYONDBUFFER' }) if($self->fh->tell + $payload_s > $self->len);

    my $pb = IO::String->new;
    $pb->binmode(1);

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
    return $o;
}

1;
