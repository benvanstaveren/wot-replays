package WR::Mission;
use Mojo::Base '-base';

has 'mission'       => undef;     # the hash from the missions collection in statterbox' db
has 'result'        => undef;     # the data in the replay 
has 'is_awarded'    => sub {
    my $self = shift;
    if($self->result->[1]->{bonusCount} < $self->result->[2]->{bonusCount}) {
        # mission was awarded
        return 1;
    } else {
        return 0;
    }
};

sub id      { return shift->mission->{_id } }
sub name    { return shift->mission->{name} }
sub desc    { return shift->mission->{description} }
sub bonuses { return shift->mission->{bonuses} }

sub progression_key {
    my $self = shift;
    my $cond = $self->mission->{conditions}->{bonus};

    if(defined($cond->{battles})) {
        return 'battlesCount';
    } elsif(defined($cond->{cumulative}->{value})) {
        return $cond->{cumulative}->{value}->[0];
    } elsif(defined($cond->{vehicleKills})) {
        return 'vehicleKills';
    }
}

sub progress_max {
    my $self = shift;
    my $cond = $self->mission->{conditions}->{bonus};

    if(defined($cond->{battles})) {
        return $cond->{battles}->{value};
    } elsif(defined($cond->{cumulative}->{value})) {
        return $cond->{cumulative}->{value}->[1];
    } elsif(defined($cond->{vehicleKills})) {
        if(defined($cond->{vehicleKills}->{greaterOrEqual})) {
            return $cond->{vehicleKills}->{greaterOrEqual}->{value};
        }
    }
}

sub progress_current {
    my $self = shift;
    my $key  = $self->progression_key;

    return $self->result->[2]->{$key};
}
     
1;
