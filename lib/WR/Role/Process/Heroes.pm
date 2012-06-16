package WR::Role::Process::Heroes;
use Moose::Role;
use WR::Res::Achievements;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    return $res unless($res->{complete});

    my $achievements = WR::Res::Achievements->new();

    my $heroes = {};
    my $offset = 0;
    foreach my $vid (@{$res->{game}->{heroes}}) {
        $vid = $vid + 0;
        my $aId = $self->match_result->[0]->{achieveIndices}->[$offset];
        push(@{$heroes->{$vid}}, $achievements->index_to_idstr($aId));
        $offset++;
    }

    $res->{game}->{heroes} = $heroes;
    return $res;
};

no Moose::Role;
1;
