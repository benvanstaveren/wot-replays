package WR::Query;
use Mojo::Base '-base';
use boolean;
use Mojo::JSON;
use DateTime;
use Data::Dumper;

# args
has 'coll'    => undef;
has 'perpage' => 15;
has 'filter'  => sub { {} };
has 'sort'    => sub { {} };

has '_res'    => undef;
has '_query'  => sub {
    return shift->_build_query;
};
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
            $self->res($cursor);
            $cb->($cursor);
        });
    }
}

sub maxp {
    my $self = shift;
    my $total = $self->total;;
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

sub fuck_mojo_json {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_mojo_json($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_mojo_json($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_mojo_json($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(boolean::isBoolean($obj->{$field})) {
                $obj->{$field} = ($obj->{$field}) ? Mojo::JSON->true : Mojo::JSON->false;
            }
        }
        return $obj;
    }
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
        'site.visible' => true,
    };

    my $ors = [];

    $query->{version} = $args{'version'} if($args{'version'});

    if($args{'player'}) {
        if($args{'playerpov'} > 0) {
            $query->{'player.name'} = $self->fixargs($args{'player'});
        } elsif($args{'playerinv'}) {
            $query->{'involved.players'} = $self->fixargs($args{'player'});
            $query->{'player.name'} = $self->fixargs($args{'player'}, '$nin');
        } else {
            push(@$ors, [ 
                { 'player.name' => $self->fixargs($args{'player'}) }, { 'vehicles.name' => $self->fixargs($args{'player'}) } 
            ]);
        }
    }

    if($args{'server'}) {
        if(ref($args{'server'}) eq 'ARRAY') {
            $query->{'player.server'} = { '$in' => $args{'server'} };
        } elsif(!ref($args{'server'})) {
            $query->{'player.server'} = $args{'server'} if($args{'server'} ne 'any');
        }
    }

    # actually args{map} contains the map slug, not it's id so find it first
    # - temporarily removed until i figure out how to do this in a non-blocking happy call-backy fashion 
=pod
    if(defined($args{map})) {
        if(my $map = $self->coll->_database->get_collection('data.maps')->find_one({ 
            '$or' => [
                { _id => $args{map} },
                { slug => $args{map} },
            ]
        })) {
            $query->{'map.id'} = $self->fixargs($map->{_id});
        } else {
            $query->{'map.id'} = 'mapdoesnotexist';
        }
    }
=cut

    if($args{'vehicle'}) {
        if($args{'vehiclepov'}) {
            $query->{'player.vehicle.full'} = $self->fixargs($args{'vehicle'});
        } elsif($args{'vehicleinv'}) {
            $query->{'vehicles.vehicleType.full'} = $self->fixargs($args{'vehicle'});
        } else {
            push(@$ors, [
                { 'player.vehicle.full' => $self->fixargs($args{'vehicle'}) },
                { 'vehicles.vehicleType.full' => $self->fixargs($args{'vehicle'}) },
            ]);
        }
    }

    $query->{'player.vehicle.tier'} = {
        '$gte' => $args{tier_min} + 0,
        '$lte' => $args{tier_max} + 0,
    };

    if($args{'clan'}) {
        if($args{'clanpov'}) {
            $query->{'player.clanAbbrev'} = $self->fixargs($args{'clan'});
        } elsif($args{'claninv'}) {
            $query->{'vehicles.clanAbbrev'} = $self->fixargs($args{'clan'});
        } else {
            push(@$ors, [ 
                { 'player.clanAbbrev' => $self->fixargs($args{'clan'}) }, 
                { 'vehicles.clanAbbrev' => $self->fixargs($args{'clan'}) } 
            ]);
        }
    }

    # is there such a thing?
    #$query->{'complete'} = true if($args{'complete'} == 1);

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

    return $query;
}

1;
