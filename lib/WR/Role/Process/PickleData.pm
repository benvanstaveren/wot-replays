package WR::Role::Process::PickleData;
use Moose::Role;
use boolean;
use WR::Util::PyPickle;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    return $res unless($self->is_complete);

    # just load up the unpickle stuff
    my $p = WR::Util::PyPickle->new(data => $self->_parser->get_block(3));
    $self->_set_pickledata($p->unpickle);

    $res->{player}->{statistics} = $self->pickledata;
    return $res;
};

no Moose::Role;
1;
