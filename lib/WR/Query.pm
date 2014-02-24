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
has 'add'     => undef;

# user doing the query
has 'user'    => undef;

has '_query'  => sub { return shift->_build_query };
has '_res'    => undef;
has 'total'   => 0;
has 'log'     => undef;
has 'explain' => sub { return shift->exec()->explain() }; # since this is usually called until way after we've done our exec, we can probably get away with this here 
has 'panel'   => 0;


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

    return {
        'site.visible' => Mango::BSON::bson_true,
    };
}

sub _privacy_recorder {
    my $self = shift;

    return {
        'site.visible'       => Mango::BSON::bson_false,
        'site.privacy'       => 2,
        'game.recorder.name' => $self->user->{player_name},
        'game.server'        => $self->user->{player_server},
    };
}

sub _privacy_clan {
    my $self = shift;

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
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'game.recorder.name'} = $self->fixargs($args{pl});
        } elsif($args{'pi'} > 0) {
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'involved.players'} = $self->fixargs($args{pl}, '$in');
            $query->{'game.recorder.name'} = $self->fixargs($args{pl}, '$nin');
        } else {
            $query->{'game.server'} = $self->fixargs($args{s});
            $query->{'$or'} = [
                { 'game.recorder.name' => $self->fixargs($args{'pl'}) }, 
                { 'involved.players' => $self->fixargs($args{'pl'}, '$in') }
            ];
        }
    }

    if($args{c}) {
        $query->{'game.recorder.clan'} = $args{c};
    }

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
