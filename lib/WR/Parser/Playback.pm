package WR::Parser::Playback;
use Mojo::Base 'Mojo::EventEmitter';

has 'stream'            => undef;
has 'type'              => undef;
has 'handlers'          => sub { [] };
has 'stopping'          => 0;
has 'pcounter'          => 0;
has 'version'           => 0;
has 'log'             => undef;

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join('', '[', ref($self), ']: ', @_);
    
    $self->log->$l($m) if(defined($self->log));
}

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub warning { shift->_log('warning', @_) }
sub fatal   { shift->_log('fatal', @_) }
sub error   { shift->_log('error', @_) }

sub start {
    my $self = shift;
    my $stopping = 0;
    my $status   = 0;

    $self->add_handlers;
    $self->emit('replay.size' => $self->stream->len);
    $self->stream->on('finish' => sub {
        my ($stream, $status) = (@_);
        $self->debug('playback stream->on finish cb');
        $self->emit(finish => $status);
        $self->stopping(1);
    });

    while(my $packet = $self->stream->next()) {
        $self->process_packet($packet);
    }

    if($self->stopping < 1) {
        $self->emit(finish => { ok => 0, reason => 'end of packets but no finish event triggered' });
    }
}

sub process_packet {
    my $self = shift;
    my $packet = shift;

    $self->pcounter($self->pcounter + 1);
    $self->emit('replay.position' => $self->stream->position) if($self->pcounter % 50 == 0);
    $self->handlers->[$packet->type]->($self, $packet) if(defined($self->handlers->[$packet->type]));
}

sub add_handler {
    my $self = shift;
    my $type = shift;
    my $sub  = shift;

    # type has to be a module 
    my $pm = sprintf('WR::Parser::Stream::Packet::%s::0x%02x', uc($self->type), $type);

    my $hsub = sub {
        my ($self, $packet) = (@_);

        $sub->($self => $packet);
    };
    $self->handlers->[$type] = $hsub;
}

1;
