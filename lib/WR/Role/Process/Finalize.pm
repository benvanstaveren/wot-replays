package WR::Role::Process::Finalize;
use Moose::Role;
use Try::Tiny;

sub apply_tags {
    my $self = shift;
    my $res  = shift;
    my $tags = [];

    return $tags;
}


around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

};

no Moose::Role;
1;
