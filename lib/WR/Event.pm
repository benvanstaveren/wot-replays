package WR::Event;
use Mojo::Base '-base';
use Mango::BSON;
use Data::Dumper;

has 'server'                =>  undef;
has 'timeless'              =>  0;
has 'start_time'            =>  undef;
has 'end_time'              =>  undef;
has 'time_field'            =>  'game.started';     # can also be site.uploaded_at 
has 'registration'          =>  undef;
has 'input'                 =>  undef;
has 'preProcess'            =>  undef;
has 'output'                =>  undef;

has 'db'                    =>  undef;
has 'log'                   =>  undef;
has '_debug'                =>  0;


sub debug { 
    my $self = shift;
    $self->log->debug(join('', @_)) if($self->_debug > 0);
}

sub get_server {
    my $self = shift;
    
    if(ref($self->server) eq 'ARRAY') {
        return { '$in' => $self->server };
    } else {
        return $self->server;
    }
}

sub model {
    my $self = shift;
    return $self->db->collection(shift);
}

sub get_leaderboard_entries {
    my $self  = shift;
    my $query = shift;
    my $base  = $self->process_match_conditions;

    # merge query and base
    foreach my $key (keys(%$query)) {
        $base->{$key} = $query->{$key} unless(defined($base->{$key}));
    }
    return $base;
}

sub _cond_ref {
    my $self = shift;
    my $cond = shift;
    my $cm   = {};

    if(defined($cond->{gte}) || defined($cond->{lte})) {
        $cm->{'$gte'} = $cond->{'gte'} + 0 if(defined($cond->{'gte'}));
        $cm->{'$lte'} = $cond->{'lte'} + 0 if(defined($cond->{'lte'}));
    } elsif(defined($cond->{in}) || defined($cond->{nin})) {
        $cm->{'$in'} = $cond->{'in'} if(defined($cond->{in}));
        $cm->{'$nin'} = $cond->{'nin'} if(defined($cond->{nin}));
    } else {
        # no idea how to deal with this ref 
    }
    return $cm;
}

sub _cond_val {
    my $self = shift;
    my $v    = shift;

    $v += 0 if($v =~ /^\d+/);
    return $v;
}

sub _cond {
    my $self = shift;
    my $cond = shift;

    if(ref($cond)) {
        return $self->_cond_ref($cond);
    } else {
        return $self->_cond_val($cond);
    }
}


sub _field_virtual {
    my $self = shift;
    my $f    = shift;
    my $c    = shift;

    # this is mainly for convenience
    my $virtmap = {
        'victory'               =>  'game.victory',
        'bonustype'             =>  'game.bonus_type',
        'gametype'              =>  'game.type',
        'vehicle'               =>  'game.recorder.vehicle.ident',
        'tier'                  =>  'game.recorder.vehicle.tier',
        'kills'                 =>  'stats.kills',
        'damageDealt'           =>  'stats.damageDealt',
        'damageAssisted'        =>  'stats.damageAssisted',             # wotreplays.org custom field, we calculate it during replay storage
        'damageAssistedRadio'   =>  'stats.damageAssistedRadio',
        'damageAssistedTrack'   =>  'stats.damageAssistedTrack',
    };

    foreach my $kf (keys(%$virtmap)) {
        if($f eq $kf) {
            return ($virtmap->{$kf}, $self->_cond($c));
        }
    }

    if($f eq 'or') {
        my $rc = [];
        foreach my $fkey (keys(%$c)) {
            $fkey =~ s/_/\./g;
            my $fc = $c->{$fkey};
            if(ref($fc)) {
                push(@$rc, { $fkey => $self->_cond_ref($fc) });
            } else {
                push(@$rc, { $fkey => $self->_cond_val($fc) });
            }
        }
        return ('$or', $rc);
    }
}

sub process_match_conditions {
    my $self    = shift;
    my $query   = {
        'game.server'     => $self->get_server,
    };
    $query->{$self->time_field} = { '$gte' => $self->start_time, '$lte' => $self->end_time } if($self->timeless < 1);


    # the rest of the match conditions are forced into an $and array so we can have multiple
    # $where clauses operating on the same query
    my $qlist = [];
    foreach my $key (keys(%{$self->input->{matchConditions}})) {
        my $field = $key;
        $field=~ s/_/\./g;

        my $cond = $self->input->{matchConditions}->{$key};

        # pick up the specials first
        if($field =~ /\@(.*)/) {
            my $real = $1;
            my ($f, $c) = $self->_field_virtual($real => $cond);
            $query->{$f} = $c;
        } elsif(ref($cond)) {
            $query->{$field} = $self->_cond_ref($cond);
        } else {
	        my $val = $self->input->{matchConditions}->{$key};
            $query->{$field} = $self->_cond_val($val);
        }
    }

    $self->debug('match_conditions: ', Dumper($query));

    return $query;
}

sub _get_aggregation_for_leaderboard {
    my $self    = shift;
    my $nolimit = shift;

    my $a = [
        { '$match' => $self->process_match_conditions },
    ];

    my $group = {
        _id => { 'player' => '$game.recorder.name', 'server' => '$game.server' },
    };

    if(defined($self->output->{config}->{project})) {
        push(@$a, { '$project' => $self->output->{config}->{project} });
    }

    $group->{$self->output->{config}->{generate}->{as}} = { '$sum' => $self->output->{config}->{generate}->{field} };

    push(@$a,
        { '$group' => $group },
        { '$sort' => { (keys(%{$self->output->{config}->{sort}}))[0] => (values(%{$self->output->{config}->{sort}}))[0] + 0 } },
    );
    push(@$a, { '$limit' => $self->output->{config}->{size} }) unless(defined($nolimit));

    $self->debug('aggregation: ', Dumper($a));

    return $a;
}

sub process {
    my $self = shift;
    my $manl = shift;
    my $cb   = shift;

    return undef unless($self->output->{type} eq 'leaderboard'); # only one we support for now
    my $agg = $self->_get_aggregation_for_leaderboard(($manl > 0) ? $manl : undef);

    if(defined($cb)) {
        if($manl > 0) {
            $self->model('replays')->aggregate($agg => sub {
                my ($c, $e, $d) = (@_);

                $self->debug('have ', scalar(@$d), ' results, manlimit');

                if(defined($e) || !defined($d)) {
                    return $cb->($self, undef);
                } 
                if(scalar(@$d) < $self->output->{config}->{size}) {
                    return $cb->($self, $d, []);
                }
                my $top = [ splice(@$d, 0, $self->output->{config}->{size}) ];
                return $cb->($self, $top, $d);
            }); 
        } else {
            $self->model('replays')->aggregate($agg => sub {
                my ($c, $e, $d) = (@_);
                $self->debug('have ', scalar(@$d), ' results, agglimit');
                $cb->($self, $d);
            });
        }
    } else {
        if($manl > 0) {
            if(my $d = $self->model('replays')->aggregate($agg)) {
                if(scalar(@$d) < $self->output->{size}) {
                    return ($d, undef);
                }
                my $top = [ splice(@$d, 0, $self->output->{config}->{size}) ];
                return ($top, $d);
            } else {
                return (undef, undef);
            }
        } else {
            return $self->model('replays')->aggregate($agg);
        }
    }
}

1;
