package WR::Query;
use Mojo::Base '-base';
use Mojo::JSON;
use Digest::SHA1;
use Mango::BSON;
use Data::Dumper;
use Time::HiRes qw/gettimeofday tv_interval/;

# args
has 'coll'    => undef;
has 'perpage' => 15;
has 'filter'  => sub { {} };
has 'sort'    => sub { {} };

# user doing the query
has 'user'    => undef;

has '_query'  => sub { return shift->_build_query };
has '_res'    => undef;
has 'total'   => 0;
has 'log'     => undef;
has 'explain' => sub { return shift->exec()->explain() }; # since this is usually called until way after we've done our exec, we can probably get away with this here 
has 'panel'   => 0;

has 'di_fields' =>  sub { {} };
has 'di_prio'   =>  sub {
    {
        'site.visible'                  => 1,
        'site.privacy'                  => 2,
        'game.server'                   => 3,
        'game.map'                      => 4,
        'game.type'                     => 5,
        'game.bonus_type'               => 6,
        'game.recorder.vehicle.ident'   => 6,
        'game.recorder.vehicle.tier'    => 7,
        'game.recorder.name'            => 8,
        'game.recorder.clan'            => 9,
        'involved.players'              => 10,
    }
};

sub dif { my $self = shift; my $n = shift; $self->di_fields->{$n}++; $self->debug('dif: ', $n) }

sub gen_dynamic_index {
    my $self = shift;
    my $i = [];
    
    foreach my $f (sort { $self->di_prio->{$a} <=> $self->di_prio->{$b} } (keys(%{$self->di_prio}))) {
        if(defined($self->di_fields->{$f})) {
            push(@$i, $f);
            delete($self->di_fields->{$f});
        }
    }

    foreach my $f (keys(%{$self->di_fields})) {
        push(@$i, $f);
    }
    
    foreach my $key (keys(%{$self->sort})) {
        push(@$i, $key);
    }

    my $idx = Mango::BSON::bson_doc(map { $_ => 1 } @$i);
    my $n = $self->coll->build_index_name($idx);
    $self->coll->ensure_index($idx, { name => sprintf('filter.%s', Digest::SHA1::sha1_hex($n)) });

    my $sortidx = Mango::BSON::bson_doc(%{$self->sort});
    my $sn = sprintf('sort.%s', Digest::SHA1::sha1_hex($self->coll->build_index_name($sortidx)));
    $self->coll->ensure_index($sortidx, { name => $sn });

}

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

# these fragments are combined in an '$or' statement for the visible and privacy level settings
sub _privacy_public {
    my $self = shift;

    $self->dif('site.visible');

    return {
        'site.visible' => Mango::BSON::bson_true,
    };
}

sub _privacy_recorder {
    my $self = shift;

    $self->dif($_) for(qw/site.visible site.privacy game.recorder.name game.server/);

    return {
        'site.visible'       => Mango::BSON::bson_false,
        'site.privacy'       => 2,
        'game.recorder.name' => $self->user->{player_name},
        'game.server'        => $self->user->{player_server},
    };
}

sub _privacy_clan {
    my $self = shift;

    $self->dif($_) for(qw/site.visible site.privacy game.recorder.clan game.server/);

    return {
        'site.visible'       => Mango::BSON::bson_false,
        'site.privacy'       => 3,
        'game.server'        => $self->user->{player_server},
        'game.recorder.clan' => $self->user->{clan}->{abbreviation},
    };
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
    my $query = [];
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
        delete($args{$key}) if($args{$key} eq '*');
        if(my $newname = $namemap->{$key}) {
            $args{$newname} = delete($args{$key});
        } 
    }

    $self->debug('raw args: ', Dumper({%args}));

    my $priv = [
        $self->_privacy_public,
    ];
    push(@$priv, $self->_privacy_recorder) if(defined($self->user) && defined($self->user->{player_name}));
    push(@$priv, $self->_privacy_clan) if(defined($self->user) && defined($self->user->{clan}));

    if($args{'pl'}) {
        if($args{'pp'} > 0) {
            push(@$query, { 
                'game.server'         => $self->fixargs($args{s}),
                'game.recorder.name'  => $self->fixargs($args{pl}),
            });
            $self->dif($_) for(qw/game.server game.recorder.name/);
        } elsif($args{'pi'} > 0) {
            push(@$query, {
                'game.server'     => $self->fixargs($args{s}),
                '$and'            => [
                    { 'involved.players' => $self->fixargs($args{'pl'}, '$in') },
                    { 'game.recorder.name' => $self->fixargs($args{'pl'}, '$nin') },
                ],
            });
            $self->dif($_) for(qw/game.server game.recorder.name involved.players/);
        } else {
            push(@$query, {
                '$or' => [
                    { 'game.recorder.name' => $self->fixargs($args{'pl'}) }, 
                    { 'involved.players' => $self->fixargs($args{'pl'}, '$in') }
                ],
                'game.server'     => $self->fixargs($args{s}),
            });
            $self->dif($_) for(qw/game.server game.recorder.name involved.players/);
        }
    }

    if($args{c}) {
        push(@$query, { 'game.recorder.clan' => $args{c} });
        $self->dif('game.recorder.clan');
    }

    if($args{'s'}) {
        if(ref($args{'s'}) eq 'ARRAY') {
            push(@$query, { 'game.server' => { '$in' => $args{'s'} } });
        } elsif(!ref($args{'server'})) {
            push(@$query, { 'game.server' => $args{'s'} });
        }
        $self->dif('game.server');
    }

    if($args{m}) {
        push(@$query, { 'game.map' => $self->fixargs($args{m}) + 0 });
        $self->dif('game.map');
    }

    if($args{'v'}) {
        if($args{'vp'}) {
            push(@$query, { 'game.recorder.vehicle.ident' => $self->fixargs($args{'v'}) });
            $self->dif('game.recorder.vehicle.ident');
        } elsif($args{'vi'}) {
            push(@$query, { 'roster.vehicle.ident' => $self->fixargs($args{'vi'}) });
            $self->dif('roster.vehicle.ident');
        } else {
            $self->dif('game.recorder.vehicle.ident');
            $self->dif('roster.vehicle.ident');
            push(@$query, { 
                '$or' => [
                    { 'game.recorder.vehicle.ident' => $self->fixargs($args{'vi'}) },
                    { 'roster.vehicle.ident' => $self->fixargs($args{'vi'}) },
                ]
            });
        }
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
            push(@$query, { 'game.recorder.vehicle.tier' => $r }) if($c > 0);
            $self->dif('game.recorder.vehicle.tier') if($c > 0);
        }
    }

    if($args{mm} && $args{mm} ne '') {
        push(@$query, { 'game.type' => $args{mm} });
        $self->dif('game.type');
    }
    if($args{mt} && $args{mt} ne '') {
        push(@$query, { 'game.bonus_type' => $args{mt} });
        $self->dif('game.bonus_type');
    }

    my $real_query = (scalar(@$query) > 0) 
        ? { '$and' => [ { '$or' => $priv }, { '$and' => $query } ] }
        : { '$or' => $priv };

    $self->gen_dynamic_index;
    return $real_query;
}

1;
