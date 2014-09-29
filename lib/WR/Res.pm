package WR::Res;
use Mojo::Base '-base';
use WR::Res::Achievements qw//;

has 'path'          =>   undef;
has 'achievements'  =>  sub { 
    my $self = shift;
    return WR::Res::Achievements->new(path => $self->path);
} 

1;
