package WR::Parser::WOT::Base;
use Mojo::Base 'WR::Parser::Base';
use IO::File ();
use Try::Tiny qw/try catch/;
use Data::Dumper;
use Mojo::JSON;
use WR::Util::Pickle;

has '_battle_result' => undef;
has 'pickle_block'   => sub { return shift->num_blocks };

# the default implementation of battle results is the pickle
sub has_battle_result {
    my $self = shift;
    my $rv = 0;

    try {
        $rv = (defined($self->get_battle_result)) ? 1 : 0;
    } catch {
        $rv = 0;
    };

    return $rv;
}

sub get_battle_result {
    my $self = shift;

    return $self->_battle_result if(defined($self->_battle_result));
    my $p = WR::Util::Pickle->new(debug => 1, data => $self->get_block($self->pickle_block));
    try {
        $self->_battle_result($p->unpickle);
    } catch {
        $self->_battle_result(undef);
    };
    return $self->_battle_result;
}

1;
