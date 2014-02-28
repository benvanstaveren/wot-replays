package WR::Process::Base;
use Mojo::Base 'Mojo::EventEmitter';
use File::Path qw/make_path/;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use WR::Parser;

has 'config'        => undef;
has 'job'           => undef;
has 'log'           => undef;

has 'file'          => sub { shift->job->data->{file} };
has 'bf_key'        => sub { return join('', map { chr(hex($_)) } (split(/\s/, shift->config->{wot}->{bf_key}))) };

sub _log {
    my $self = shift;
    my $l    = shift;

    $self->log->$l(join('', '[', ref($self), ']: ', @_));
}

sub debug { shift->_log('debug', @_) }
sub info { shift->_log('info', @_) }
sub error { shift->_log('error', @_) }

sub cleanup {
    my $self = shift;
    my $cb   = shift;

    return $cb->();
}

sub process {
    my $self    = shift;
    my $cb      = shift;

    $self->debug('process top');

    my %args = (
        bf_key  => $self->bf_key,
        file    => $self->file,
    );
    
    my $parser;
    try {
        $self->debug('instantiating parser');
        $parser = WR::Parser->new(%args);
        $self->debug('parser instantiated');
    } catch {
        my $e = $_;
        $parser = undef;
        $self->job->set_error('Could not instantiate parser: ', $e => sub {
            $self->error('Could not instantiate parser: ', $e);
            return $cb->();
            exit(0);
        });
    };
    return unless (defined($parser));
    $self->debug('have parser, going to call -> process_replay');
    $self->process_replay($parser => sub {
        # call cleanup on self
        return $self->cleanup($cb);
    });
}

1;
