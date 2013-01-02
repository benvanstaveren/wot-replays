package WR::Role::Process::Mastery;
use Moose::Role;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res = $self->$orig;

    return $res unless($self->is_complete());
    return $res unless(defined($res->{statistics}->{dossierPopUps}));

    $res->{player}->{mastery} = 0;

    foreach my $i (@{$res->{statistics}->{dossierPopUps}}) {
        if($i->[0] == 79) {
            # must be a mastery badge, only thing that makes sense at 3 
            $res->{player}->{mastery} = $i->[1];
            last;
        }
    }
    return $res;
};

no Moose::Role;
1;
