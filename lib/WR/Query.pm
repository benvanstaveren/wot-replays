package WR::Query;
use Mojo::Base '-base';
use Mojo::JSON;
use Mango::BSON;
use Data::Dumper;
use Time::HiRes qw/gettimeofday tv_interval/;
use WR::PrivacyManager;

# args
has 'coll'    => undef;
has 'perpage' => 15;
has 'filter'  => sub { {} };
has 'sort'    => sub { {} };
has 'add'     => undef;

# user doing the query
has 'user'    => undef;

has '_query'  => sub { return shift->_build_query };
has '_res'    => undef;
has 'total'   => 0;
has 'log'     => undef;
has 'panel'   => 0;

has 'pm' => sub { 
    my $self = shift;
    return WR::PrivacyManager->new(user => $self->user);
};

sub error { shift->_log('error', @_) }
sub info { shift->_log('info', @_) }
sub warning { shift->_log('warn', @_) }
sub debug { shift->_log('debug', @_) } 

sub _log {
    my $self = shift;
    my $level = shift;
    my $msg = join(' ', '[WR::Query]', @_);

    $self->log->$level($msg) if(defined($self->log));
}

sub exec {
    my $self = shift;
    my $cb   = shift;

    if(defined($self->_res)) {
        $self->debug('exec already has result');
        if(!defined($cb)) {
            return $self->_res;
        } else {
            $cb->($self->_res);
        }
    } else {
        $self->debug('exec has no result yet');
        $self->coll->find($self->_query)->count(sub {
            my ($c, $e, $count) = (@_);
            $self->total($count);
            $self->_res($c);
            $self->debug('exec fetched result, stored, have ', $count, ' docs');
            $cb->($c);
        });
    }
}

sub maxp {
    my $self = shift;
    my $total = $self->total;
    my $perpage = $self->perpage;
    my $maxp = int($total/$perpage);
    $maxp++ if($maxp * $perpage < $total);
    return $maxp;
}

sub page {
    my $self = shift;
    my $page = shift || 1;
    my $cb   = shift;
    my $as_cursor = 0;

    if(ref($page) eq 'HASH') {
        $as_cursor = (defined($page->{as_cursor}) && $page->{as_cursor} > 0) ? 1 : 0;
        $page      = $page->{page} || 1;
    }

    my $offset = ($page - 1) * $self->perpage;

    $self->exec(sub {
        my $cursor = shift;
        $cursor->sort($self->sort) if($self->sort);
        $cursor->skip($offset);
        $cursor->limit($self->perpage);

        $self->debug('page: skip: ', $offset, ' limit: ', $self->perpage);

        # if we're doing panels...
        if($self->panel) {
            $self->debug('doing panel');
            $cursor->fields({
                panel   => 1,
                site    => 1,
                file    => 1,
                'game.started' => 1,
            });
        }

        if($as_cursor) {
            $cb->($self, $cursor);
        } else {
            $cursor->all(sub {
                my ($c, $e, $d) = (@_);

                if($e) {
                    $cb->($self, undef);
                } else {
                    $cb->($self, $d);
                }
            });
        }
    });
}

sub fixargs {
    my $self = shift;
    my $arg  = shift;
    my $want = shift;

    if(ref($arg) eq 'ARRAY') {
        return { ($want) ? $want : '$in' => $arg };
    } else {
        return ($want) ? { $want => [ $arg ] } : $arg;
    }
}

sub _build_query {
    my $self = shift;
    my %args = (
        pp => 0,
        pi => 0,
        vp => 0,
        vi => 0,
        %{ $self->filter },
        );
    my $query = {};
    my $namemap = {
        'playerpov'     => 'pp',
        'playerinv'     => 'pi',
        'vehiclepov'    => 'vp',
        'vehicleinv'    => 'vi',
        'tier_min'      => 'tmi',
        'tier_max'      => 'tma',
        'map'           => 'm',
        'server'        => 's',
        'matchmode'     => 'mm',
        'matchtype'     => 'mt',
        'sort'          => 'sr',
        'vehicle'       => 'v',
        'clan'          => 'c',
        'player'        => 'pl',
    };

    # convert any old names to new names (yey)
    foreach my $key (keys(%args)) {
        delete($args{$key}) if(!defined($args{$key}));
        delete($args{$key}) if(defined($args{$key}) && $args{$key} eq '*');
        $args{$newname} = delete($args{$key}) if(my $newname = $namemap->{$key});
    }

    my $priv = $self->pm->for_query;

    if($args{'pl'}) {
        if($args{'pp'} > 0) {
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'game.recorder.name'} = $self->fixargs($args{pl}, '$in');
        } elsif($args{'pi'} > 0) {
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'involved.players'} = $self->fixargs($args{pl}, '$in');
            $query->{'game.recorder.name'} = $self->fixargs($args{pl}, '$nin');
        } else {
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'$or'} = [
                { 'game.recorder.name' => $self->fixargs($args{'pl'}, '$in') }, 
                { 'involved.players' => $self->fixargs($args{'pl'}, '$in') }
            ];
        }
    }

    $query->{'game.recorder.clan'} = $args{c} if(defined($args{c}));

    if($args{'s'}) {
        if(ref($args{'s'}) eq 'ARRAY') {
            $query->{'game.server'} = { '$in' => $args{s} } unless(defined($query->{'game.server'})); # if we already have it, can't specify it again because the player has
        } elsif(!ref($args{'server'})) {
            $query->{'game.server'} = $args{s} unless(defined($query->{'game.server'})); # if we already have it, can't specify it again because the player has
        }
    }

    if($args{m}) {
        $query->{'game.map'} = $self->fixargs($args{m} + 0);
    }

    if($args{'v'}) {
        # no longer support involved vehicles 
        $query->{'game.recorder.vehicle.ident'} = $self->fixargs($args{v});
    } else {
        if(defined($args{'tmi'}) || defined($args{'tma'})) { 
            my $c = 0;
            my $r = {};
            $self->debug('tmi: ', $args{tmi}, ' tma: ', $args{tma});
            if($args{tmi} + 0 > 1) {
                $r->{'$gte'} = $args{tmi};
                $c++;
            }
            if($args{tma} + 0 < 10) {
                $r->{'$lte'} = $args{'tma'};
                $c++;
            }
            $self->debug('c: ', $c);
            $query->{'game.recorder.vehicle.tier'} = $r if($c > 0);
        }
    }

    if($args{mm} && $args{mm} ne '') {
        $query->{'game.type'} = $args{mm};
    }
    if($args{mt} && $args{mt} ne '') {
        $query->{'game.bonus_type'} = $args{mt} + 0;
    }

    if(defined($self->add)) {
        foreach my $key (keys(%{$self->add})) {
            $query->{$key} = $self->add->{$key};
        }
    }
    my $real_query = (scalar(keys(%$query)) > 0) 
        ? { '$and' => [ { '$or' => $priv },  $query ] }
        : { '$or' => $priv };

    $self->debug('QUERY: ', Dumper($real_query));

    return $real_query;
}

1;
