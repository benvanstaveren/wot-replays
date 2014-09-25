package Rube::Base;
use Mojo::Base '-base';

has 'site_folder'   => undef;
has 'wot_folder'    => undef;
has 'res_u_folder'  => undef; 
has 'img_folder'    => undef;
has 'version'       => undef;

has 'log'           => undef;

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    return $self->_build;
}

sub _log { 
    my $self = shift;
    my $l    = shift;
    
    $self->log->$l(join('', '[', ref($self), ']: ', @_));
}

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub warning { shift->_log('warning', @_) }
sub error   { shift->_log('error', @_) }
sub fatal   { shift->_log('fatal', @_) }

sub _build {}

1;
