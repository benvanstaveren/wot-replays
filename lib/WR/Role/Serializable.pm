package WR::Role::Serializable;
use Moose::Role;
use Try::Tiny;

has 'serializable' => (is => 'ro', isa => 'ArrayRef', default => sub { {} }, traits => [qw/Array/], handles => { 'add_serializable' => 'push' });

sub serialize {
    my $self = shift;
    my $s    = {};

    foreach my $field (@{$self->serializable}) {
        $s->{$field} = $self->_serialize($self->$field());
    }
    return $s;
}

sub _serialize {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));
    return $obj->serialize if(blessed($obj) && $obj->does('WR::Role::Serializable'));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->_serialize($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->_serialize($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->_serialize($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            }
        }
        return $obj;
    }
}

no Moose::Role;
1;
