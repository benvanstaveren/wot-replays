package WR::Query;
use Mojo::Base '-base';
use Mojo::JSON;
use Mango::BSON;
use Data::Dumper;

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

sub exec {
    my $self = shift;
    my $cb   = shift;

    if(defined($self->_res)) {
        $cb->($self->_res);
    } else {
        my $cursor = $self->coll->find($self->_query);
        $cursor->count(sub {
            my ($c, $e, $count) = (@_);
            $self->total($count);
            $self->_res($cursor);
            $cb->($cursor);
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

    $self->exec(sub {
        my $cursor = shift;
        $cursor->sort($self->sort) if($self->sort);
        $cursor->skip($offset);
        $cursor->limit($self->perpage);

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
            $query->{'game.server'} = $args{'server'} if($args{'server'} ne 'any');
        }
    }

    $query->{'game.map'} = $self->fixargs($args{map} + 0) if(defined($args{map}));

    if($args{'vehicle'}) {
        if($args{'vehiclepov'}) {
            $query->{'game.recorder.vehicle.id'} = $self->fixargs($args{'vehicle'});
        } elsif($args{'vehicleinv'}) {
            $query->{'roster.vehicle.id'} = $self->fixargs($args{'vehicle'});
        } else {
            push(@$ors, [
                { 'game.recorder.vehicle.id' => $self->fixargs($args{'vehicle'}) },
                { 'roster.vehicle.id' => $self->fixargs($args{'vehicle'}) },
            ]);
        }
    }

    $query->{'game.recorder.vehicle.tier'} = {
        '$gte' => $args{tier_min} + 0,
        '$lte' => $args{tier_max} + 0,
    };


    $query->{'game.type'} = $args{'matchmode'} if($args{'matchmode'} && $args{'matchmode'} ne '');
    $query->{'game.bonus_type'} = $args{'matchtype'} + 0 if($args{'matchtype'} && $args{'matchtype'} ne '');

    # finalize the query
    if(scalar(@$ors) > 1) {
        foreach my $or (@$ors) {
            push(@{$query->{'$and'}}, { '$or' => $or });
        }
    } elsif(scalar(@$ors) > 0) {
        $query->{'$or'} = shift(@$ors);
    }

    warn 'WR::Query->build_query:', "\n", Dumper($query), "\n";

    return $query;
}

1;
