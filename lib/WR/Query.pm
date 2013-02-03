package WR::Query;
use Moose;
use namespace::autoclean;
use boolean;
use Mojo::JSON;
use DateTime;
use Data::Dumper;

# args
has 'coll' => (is => 'ro', isa => 'MongoDB::Collection', required => 1);
has 'perpage' => (is => 'ro', isa => 'Num', required => 1, default => 15);
has 'filter' => (is => 'ro', isa => 'HashRef', required => 1, default => sub { {} });
has 'sort' => (is => 'ro', isa => 'HashRef', required => 0);

has '_res' => (is => 'ro', isa => 'MongoDB::Cursor', writer => '_set_res');
has '_query' => (is => 'ro', isa => 'HashRef', required => 1, lazy => 1, builder => '_build_query');
has 'total' => (is => 'ro', isa => 'Num', required => 1, default => 0, writer => '_set_total');

sub exec {
    my $self = shift;

    return($self->_res) if(defined($self->_res));
    my $cursor = $self->coll->find($self->_query);
    $self->_set_total($cursor->count());
    $self->_set_res($cursor);
    return $cursor;
}

sub maxp {
    my $self = shift;
    my $total = $self->exec()->count();
    my $perpage = $self->perpage;
    my $maxp = int($total/$perpage);
    $maxp++ if($maxp * $perpage < $total);

    return $maxp;
}

sub page {
    my $self = shift;
    my $page = shift || 1;

    my $offset = ($page - 1) * $self->perpage;

    my $cursor = $self->exec();
    $cursor->sort($self->sort) if($self->sort);
    $cursor->skip($offset);
    $cursor->limit($self->perpage);

    return [ 
        map { $self->fuck_tt($_) } $cursor->all() 
    ];
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
        compatible => 0,
        tier_min => 1,
        tier_max => 10,
        %{ $self->filter },
        );

    my $query = {
        'site.visible' => true,
    };

    my $ors = [];

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
    if(defined($args{map})) {
        if(my $map = $self->coll->_database->get_collection('data.maps')->find_one({ _id => $args{map} })) {
            $query->{'map.id'} = $self->fixargs($map->{_id});
        } else {
            $query->{'map.id'} = 'mapdoesnotexist';
        }
    }

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

    #$query->{'player.vehicle.tier'} = {
    #    '$gte' => $args{tier_min} + 0,
    #    '$lte' => $args{tier_max} + 0,
    #};

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

    $query->{'complete'} = true if($args{'complete'} == 1);
    $query->{'version'} = $args{'version'} if($args{'compatible'} == 1); 

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

    use Data::Dumper;
    warn 'query: ', Dumper($query);

    return $query;
}

1;
