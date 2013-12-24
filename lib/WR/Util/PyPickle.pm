package WR::Util::PyPickle;
use Mojo::Base '-base';

has 'data' => undef;

use Inline Python => <<'...';
import cPickle
from os import _exit

def cPickle_loads(data):
    return cPickle.loads(data);
...

sub unpickle {
    my $self = shift;
    my $data = $self->data;

    return cPickle_loads($data);
}

sub DESTROY {

}

1;
