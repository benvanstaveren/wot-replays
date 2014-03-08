use Mojo::Base -strict;
use Test::More tests => 8;

use_ok('WR::Util::QuickDB');
my $db = new_ok('WR::Util::QuickDB');

# poke some data in
push(@{$db->data}, 
    { id => 1, name => 'foo', extra => 'bar', cake => 1 },
    { id => 2, name => 'bork', extra => 'bar', cake => 2 },
    { id => 3, name => 'blork', extra => 'baz', cake => 1 },
    { id => 4, name => 'glork', extra => 'baz', cake => 2 },
    { id => 5, name => 'eep', extra => 'fnork', cake => 2 },
);

ok(defined($db->get(id => 1)));
is($db->get(id => 1)->{name}, 'foo');
is(scalar($db->all(extra => 'baz')), 2);
is($db->get_multi(cake => 2, extra => 'bar')->{id}, 2);
is($db->get_multi(cake => 1, extra => 'bar')->{id}, 1);
is($db->get_multi(cake => 1, extra => 'fnork'), undef);
