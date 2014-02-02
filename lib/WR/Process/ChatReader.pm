package WR::Process::ChatReader;
use Mojo::Base 'Mojo::EventEmitter';
use File::Path qw/make_path/;
use Data::Dumper;
use Try::Tiny qw/try catch/;

use WR::Parser;

has 'file'          => undef;
has 'bf_key'        => undef;
has 'log'           => undef;
has '_error'        => undef;
has '_parser'       => undef;
has 'has_error'     => 0;

sub _log {
    my $self = shift;
    my $level = shift;
    my $msg  = join(' ', @_);

    $self->log->$level($msg);
}

sub warning { shift->_log('warn', @_) }
sub log_error { shift->_log('error', @_) }
sub info { shift->_log('info', @_) }
sub debug { shift->_log('debug', @_) }

sub error {
    my $self = shift;
    my $message = join(' ', @_);

    if(scalar(@_) > 0) {
        $self->_error($message);
        $self->log_error($message);
        $self->has_error(1);
    } else {
        return $self->_error;
    }
}

sub process {
    my $self        = shift;
    my $prepared_id = shift;

    my $replay;

    try {
        $replay = $self->_real_process($prepared_id);
    } catch {
        my $e = $_;
        $self->error($e);
    };
    return undef;
}

sub _real_process {
    my $self = shift;
    my $prepared_id = shift;

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );
    
    my $parser;

    try {
        $parser = WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_);
        die('Unable to parse replay: ', $_);
    };

    $self->_parser($parser);

    # just use the stream instead
    if(my $stream = $self->_parser->stream()) {
        while(my $packet = $stream->next()) {
            $self->emit(message => $packet->text) if($packet->type == 0x1f);
        }
    }
    $self->emit('finished');
    return undef;
}


1;
