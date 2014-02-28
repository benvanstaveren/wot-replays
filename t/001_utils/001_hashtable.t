use Mojo::Base -strict;
use Test::More tests => 9;

use_ok('WR::HashTable');
my $ht = new_ok('WR::HashTable');

# poke a bit of data in
$ht->data({
    foo => {
        bar => {
            baz => 'fnork',
        },
    },
    fnork => {
        bar => [ 'a', 'b', 'c' ],
    }
});

ok(defined($ht->get('foo.bar.baz')), 'foo.bar.baz defined');
ok(defined($ht->get('fnork.bar')), 'fnork.bar defined');
is($ht->get('foo.bar.baz'), 'fnork', 'foo.bar.baz is fnork');
is_deeply($ht->get('fnork.bar'), [ 'a', 'b', 'c' ], 'fnork.bar is [ a, b, c ]');

my $fnork_bar = $ht->get('fnork.bar');
push(@$fnork_bar, 'd', 'e');

is_deeply($ht->get('fnork.bar'), [ 'a', 'b', 'c', 'd', 'e' ], 'fnork.bar is [ a, b, c, d, e ] after pushing');

$ht->delete('fnork.bar');

is($ht->get('fnork.bar'), undef, 'fnork.bar is deleted');

$ht->set('foo.bar.baz' => 'yeah');
is($ht->get('foo.bar.baz'), 'yeah', 'foo.bar.baz is now yeah');

