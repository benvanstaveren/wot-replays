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
has '_query'  => sub {
    return shift->_build_query;
};
has '_res'    => undef;
has 'total'   => 0;
has 'log'     => undef;
has 'query_explain' => undef;

has 'panel'   => 0;

sub error { shift->_log('error', @_) }
sub info { shift->_log('info', @_) }
sub warning { shift->_log('warn', @_) }
sub debug { shift->_log('info', @_) } # yes, info...

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
        $cb->($self->_res);
    } else {
        $self->debug('exec has no result yet');
        $self->coll->find($self->_query)->count(sub {
            my ($c, $e, $count) = (@_);
            $self->total($count);
            $self->_res($c);
            $self->debug('exec fetched result, stored');
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

    my $offset = ($page - 1) * $self->perpage;

    $self->debug('[page]: offset: ', $offset, ' sort is set to: ', Dumper($self->sort));

    $self->exec(sub {
        my $cursor = shift;
        $cursor->sort($self->sort) if($self->sort);
        $cursor->skip($offset);
        $cursor->limit($self->perpage);

        # if we're doing panels...
        if($self->panel) {
            $cursor->fields({
                panel => 1,
                site  => 1,
                file  => 1,
            });
        }

        $cursor->all(sub {
            my ($c, $e, $d) = (@_);

            if($e) {
                $cb->(undef);
            } else {
                $cb->([ map { $self->fuck_tt($_) } @$d ]);
            }
        });
    });
}

sub fuck_tt {
    my $self = shift;
    my $o = shift;

    $o->{id} = $o->{_id};
    return $o;
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
        playerpov => 0,
        playerinv => 0,
        vehiclepov => 0,
        vehicleinv => 0,
        tier_min => 1,
        tier_max => 10,
        %{ $self->filter },
        );

    my $query = {
        'site.visible' => Mango::BSON::bson_true,
    };

    foreach my $key (keys(%args)) {
        delete($args{$key}) if($args{$key} eq '*');
    }

    my $ors = [];

    $query->{version} = $args{'version'} if($args{'version'});

    if($args{'player'}) {
        if($args{'playerpov'} > 0) {
            $query->{'game.recorder.name'} = $self->fixargs($args{'player'});
        } elsif($args{'playerinv'}) {
            $query->{'involved.players'} = $self->fixargs($args{'player'}, '$in'); 
            $query->{'game.recorder.name'} = $self->fixargs($args{'player'}, '$nin');
        } else {
            push(@$ors, [ 
                { 'game.recorder.name' => $self->fixargs($args{'player'}) }, { 'involved.players' => $self->fixargs($args{'player'}, '$in') } 
            ]);
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

    $query->{'game.recorder.vehicle.tier'} = {
        '$gte' => $args{tier_min} + 0,
        '$lte' => $args{tier_max} + 0,
    };


    $query->{'game.type'} = $args{'matchmode'} if($args{'matchmode'} && $args{'matchmode'} ne '');
    $query->{'game.bonus_type'} = $args{'matchtype'} + 0 if($args{'matchtype'} && $args{'matchtype'} ne '');

    # if the wn7 flag is set we need to use min and max to obtain it
    $query->{'wn7.data.overall'} = { '$gte' => $args{wn7} } if(defined($args{'wn7'}));
    $query->{'wn7.data.battle'} = { '$gte' => $args{wn7_battle} } if(defined($args{'wn7_battle'}));

    # finalize the query
    if(scalar(@$ors) > 1) {
        foreach my $or (@$ors) {
            push(@{$query->{'$and'}}, { '$or' => $or });
        }
    } elsif(scalar(@$ors) > 0) {
        $query->{'$or'} = shift(@$ors);
    }

    $self->debug('[_build_query]: built query: ', Dumper($query));

    return $query;
}

1;
