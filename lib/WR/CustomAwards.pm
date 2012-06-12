package WR::CustomAwards;
use Mojo::Base '-base';

use constant AWARDS => {
    'scope_dope' => sub {
        my $self = shift;
        my $kills = scalar(@{$self->{player}->{statistics}->{killed}});
        my $shots = $self->{player}->{statistics}->{shots}->{fired};
        my $hits = $self->{player}->{statistics}->{shots}->{hits};

        return 1 if($hits > 0 && $shots == $hits && $kills == $shots);
        return 0;
    },
};

sub process {
    my $self = shift;
    my $replay = shift;
    my $awards = [];

    foreach my $award (keys(%{$self->AWARDS})) {
        my $rv = $self->AWARDS->{$award}->($replay);
        push(@$awards, sprintf('custom_%s', $award)) if($rv);
    }
}

1;
