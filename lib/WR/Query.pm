package WR::Query;
use Mojo::Base '-base';
use Mojo::JSON;
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
has 'query_explain' => sub { return shift->exec()->explain() }; # since this is usually called until way after we've done our exec, we can probably get away with this here 
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
                panel => 1,
                site  => 1,
                file  => 1,
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
        playerpov => 0,
        playerinv => 0,
        vehiclepov => 0,
        vehicleinv => 0,
        %{ $self->filter },
        );
    my $query = {};

    foreach my $key (keys(%args)) {
        delete($args{$key}) if($args{$key} eq '*');
    }

    my $ors = [];

    my $priv = [
        $self->_privacy_public,
    ];

    push(@$priv, $self->_privacy_recorder) if(defined($self->user) && defined($self->user->{player_name}));
    push(@$priv, $self->_privacy_clan) if(defined($self->user) && defined($self->user->{clan}));

    if($args{'player'}) {
        if($args{'playerpov'} > 0) {
            $query->{'game.server'} = $self->fixargs($args{'server'});
            $query->{'game.recorder.name'} = $self->fixargs($args{'player'});
        } elsif($args{'playerinv'} > 0) {
            $query->{'game.server'} = $self->fixargs($args{'server'});
            $query->{'involved.players'} = $self->fixargs($args{'player'}, '$in'); 
            $query->{'game.recorder.name'} = $self->fixargs($args{'player'}, '$nin');
        } else {
            push(@$ors, [ 
                { 'game.recorder.name' => $self->fixargs($args{'player'}) }, { 'involved.players' => $self->fixargs($args{'player'}, '$in') } 
            ]);
            $query->{'game.server'} = $self->fixargs($args{'server'});
        }
    }

    if($args{'server'}) {
        if(ref($args{'server'}) eq 'ARRAY') {
            $query->{'game.server'} = { '$in' => $args{'server'} };
        } elsif(!ref($args{'server'})) {
            $query->{'game.server'} = $args{'server'} if($args{'server'} ne 'www');
        }
    }

    $query->{'game.map'} = $self->fixargs($args{map} + 0) if(defined($args{map}));

    if($args{'vehicle'}) {
        if($args{'vehiclepov'}) {
            $query->{'game.recorder.vehicle.ident'} = $self->fixargs($args{'vehicle'});
        } elsif($args{'vehicleinv'}) {
            $query->{'roster.vehicle.ident'} = $self->fixargs($args{'vehicle'});
        } else {
            push(@$ors, [
                { 'game.recorder.vehicle.ident' => $self->fixargs($args{'vehicle'}) },
                { 'roster.vehicle.ident' => $self->fixargs($args{'vehicle'}) },
            ]);
        }
    }

    if(defined($args{'tier_min'}) || defined($args{'tier_max'})) {
        $query->{'game.recorder.vehicle.tier'} = {
            '$gte' => (defined($args{'tier_min'})) ? $args{tier_min} + 0 : 1,
            '$lte' => (defined($args{'tier_max'})) ? $args{tier_max} + 0 : 10,
        };
    }

    $query->{'game.type'} = $args{'matchmode'} if($args{'matchmode'} && $args{'matchmode'} ne '');
    $query->{'game.bonus_type'} = $args{'matchtype'} + 0 if($args{'matchtype'} && $args{'matchtype'} ne '');

    # finalize the query
    if(scalar(@$ors) > 1) {
        foreach my $or (@$ors) {
            push(@{$query->{'$and'}}, { '$or' => $or });
        }
    } elsif(scalar(@$ors) > 0) {
        $query->{'$or'} = [ shift(@$ors), @$priv ]
    } else {
        $query->{'$or'} = $priv;
    }

    $self->debug('[_build_query]: built query: ', Dumper($query));

    return $query;
}

1;
