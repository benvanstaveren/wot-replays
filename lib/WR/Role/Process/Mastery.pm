package WR::Role::Process::Mastery;
use Moose::Role;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res = $self->$orig;

    warn __PACKAGE__, ': process', "\n";

    return $res unless($self->is_complete());

    # awarding of mastery badges is something that's a pain in the bloody arse, 
    # mainly because there's this thing where we can't reliably tell the initial mastery level
    # of any tank before it's actually set, so we pull some shenanigans...

    $res->{player}->{statistics}->{mastery} = $self->award_mastery(
        $res->{player}->{id}, 
        $res->{player}->{vehicle}->{full}, 
        $res->{player}->{statistics}->{mastery} 
    );
    return $res;
};

sub award_mastery {
    my $self = shift;
    my $playerid = shift;
    my $vehicle  = shift;
    my $mastery  = shift;

    return 0 unless($mastery > 0);

    if(my $rec = $self->db->get_collection('track.mastery')->find_one({ _id => sprintf('%s_%s', $playerid, $vehicle) })) {
        if($mastery > $rec->{value}) {
            $self->db->get_collection('track.mastery')->update(
                {
                    _id => sprintf('%s_%s', $playerid, $vehicle)
                },
                {
                    '$set' => {
                        'value' => $mastery
                    },
                }
            );
            return $mastery;
        } else {
            return 0;
        }
    } else {
        $self->db->get_collection('track.mastery')->save({ _id => sprintf('%s_%s', $playerid, $vehicle), 'value' => $mastery });
        return 0; # no mastery this first time
    }
}


1;
