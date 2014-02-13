package WR::Util::PyPickle;
use Mojo::Base '-base';

has 'data' => undef;

use Inline Python => <<'...';
import sys
import cPickle
import StringIO

class SafeUnpickler(object):
    PICKLE_SAFE = {
        'copy_reg': set(['_reconstructor']),
        '__builtin__': set(['object'])
    }

    @classmethod
    def find_class(cls, module, name):
        if not module in cls.PICKLE_SAFE:
            raise cPickle.UnpicklingError(
                'Attempting to unpickle unsafe module %s' % module
            )
        __import__(module)
        mod = sys.modules[module]
        if not name in cls.PICKLE_SAFE[module]:
            raise cPickle.UnpicklingError(
                'Attempting to unpickle unsafe class %s' % name
            )
        klass = getattr(mod, name)
        return klass

    @classmethod
    def loads(cls, pickle_string):
        pickle_obj = cPickle.Unpickler(StringIO.StringIO(pickle_string))
        pickle_obj.find_global = cls.find_class
        return pickle_obj.load()

def cPickle_loads(data):
    return SafeUnpickler.loads(data);
...

sub unpickle {
    my $self = shift;
    my $data = $self->data;

    return cPickle_loads($data);
}

sub DESTROY {
}

1;
