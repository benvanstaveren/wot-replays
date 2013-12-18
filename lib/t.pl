#!/usr/bin/perl
use strict;
use warnings;
use WR;
use Mango;
use Mojo::Util qw/monkey_patch/;
use Scalar::Util qw/blessed/;

monkey_patch 'Mango::Cursor', 
    'all_with_cb' => sub {
        my ($self, $cb) = (@_);
        warn 'all with cb', "\n";
        return $self->next(sub { shift->_acb_next($cb, @_) });
    },
    '_acb_next' => sub {
        warn 'acb_next', "\n";
        my ($self, $cb, $err, $doc) = (@_);
        return $self->_defer($cb, undef) if($err || !$doc);
        $cb->($doc);
        $self->next(sub { shift->_acb_next($cb, @_) });
    };


my $m = Mango->new('mongodb://localhost:27017/');
my $d = $m->db('wot-replays');
my $c = $d->collection('data.maps');

my $cursor = $c->find();

$cursor->all_with_cb(sub {
    my $doc = shift;

    if(!blessed($doc)) {
        warn 'got doc, id: ', $doc->{_id}, "\n";
    } else {
        warn 'end', "\n";
        exit(0);
    }
});

Mojo::IOLoop->start unless(Mojo::IOLoop->is_running);
