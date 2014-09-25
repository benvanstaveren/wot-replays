package WR::Parser::Base;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;
use Data::Dumper qw/Dumper/;
use Mojo::JSON;
use WR::Parser::Stream qw//;
use WR::Bigworld::Replay::Unpack qw//;
use Module::Load qw/load/;

has 'blowfish_keys'   => undef;
has 'unpacked'        => undef;
has 'upgraded'        => 0;
has 'log'             => undef;

use constant SEEK_SET => 1;

sub upgrade {
    my $self = shift;
    my $cb   = shift;

    if(my $key = $self->blowfish_keys->{$self->type}) {
        my $unpacker = WR::Bigworld::Replay::Unpack->new(fh => $self->get_data, blowfish_key => $key);
        $self->unpacked($unpacker->unpack);
        $self->upgraded(1);
        return (defined($cb)) ? $cb->($self, 1) : 1;
    } else {
        return (defined($cb)) ? $cb->($self, undef, 'No blowfish key') : undef;
    }
}

sub get_data {
    my $self = shift;

    my $out = IO::String->new();
    $out->binmode(1);
    $self->fh->seek($self->data_offset, SEEK_SET);
    while($self->fh->read(my $buf, 1024)) {
        $out->write($buf);
    }
    $out->seek(0, SEEK_SET);
    return $out;
}

sub stream {
    my $self = shift;

    return undef unless($self->upgraded);
    return WR::Parser::Stream->new(type => $self->type, fh => $self->unpacked, log => $self->log, version => $self->version);
}

sub game { return shift->playback(@_) }
sub playback {
    my $self = shift;
    
    return undef unless($self->upgraded);
    my $module = sprintf('WR::Parser::Playback::%s', uc($self->type));
    load $module;
    return $module->new(type => $self->type, version => $self->version, stream => $self->stream, log => $self->log, version => $self->version);
}

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join('', '[WR::Parser]: ', @_);
    
    $self->log->$l($m) if(defined($self->log));
}

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub warning { shift->_log('warning', @_) }
sub fatal   { shift->_log('fatal', @_) }
sub error   { shift->_log('error', @_) }

1;
