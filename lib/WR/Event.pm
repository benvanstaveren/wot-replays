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

our $DEBUG = 0;

sub debug { shift->log->debug(join('', @_)) if($DEBUG > 0) }

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

sub process_match_conditions {
    my $self    = shift;
    my $query   = {
        'game.server'     => $self->server,
    };
    $query->{$self->time_field} = { '$gte' => $self->start_time, '$lte' => $self->end_time } if($self->timeless < 1);
    foreach my $key (keys(%{$self->input->{matchConditions}})) {
        my $field = $key;
        $field=~ s/_/\./g;

        my $cond = $self->input->{matchConditions}->{$key};
        if(ref($cond)) {
            my $cm = {};
            $cm->{'$gte'} = $cond->{'gte'} + 0 if(defined($cond->{'gte'}));
            $cm->{'$lte'} = $cond->{'lte'} + 0 if(defined($cond->{'lte'}));
            $query->{$field} = $cm;
        } else {
            $query->{$field} = $self->input->{matchConditions}->{$key};
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
