package WR::Role::Process::Epic;
use Moose::Role;
use WR::Res::Achievements;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    return $res unless($res->{complete});

    my $achievements = WR::Res::Achievements->new();
    $res->{player}->{statistics}->{epic} => [ map { $achievements->index_to_epic_idstr($_ + 0) } @{$self->match_result->[0]->{epicAchievements}} ],
    return $res;
};

no Moose::Role;
1;
