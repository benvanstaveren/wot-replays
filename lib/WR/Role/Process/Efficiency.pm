package WR::Role::Process::Efficiency;
use Moose::Role;
use WR::PlayerProfileData;
use Try::Tiny qw/catch try/;

sub get_player_id {
    my $self = shift;
    my $res  = shift;
    my $name = shift;

    foreach my $id (keys(%{$res->{players}})) {
        return $id if($res->{players}->{$id}->{name} eq $name);
    }
    return undef;
}

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    $res->{efficiency} = {};

    if(my $playerid = $self->get_player_id($res => $res->{player}->{name})) {
        my $ppd = WR::PlayerProfileData->new(
            db      => $self->db,
            id      => $playerid + 0,
            name    => $res->{player}->{name},
            server  => $res->{player}->{server},
        );
        $res->{efficiency}->{$res->{player}->{name}} = $ppd->efficiency();
    }
    return $res;
};

no Moose::Role;
1;
