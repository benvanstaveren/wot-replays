import cPickle;


a = { "key": "value" };
b = [ 'foo', 'bar' ];

print cPickle.dumps(a, 1);
print cPickle.dumps(b, 1);

