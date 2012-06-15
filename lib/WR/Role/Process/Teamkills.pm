package WR::Role::Process::Teamkills;
use Moose::Role;
use WR::ServerFinder;
use Try::Tiny;

sub find_user {
    my $self = shift;
    my $id   = shift;
    my $server = shift;

    my $coll = $self->db->get_collection('cache.server_finder');

    if(my $r = $coll->find_one({ user_id => $id, server => $server })) {
        return $r->{user_name};
    } else {
        my $sf = WR::ServerFinder->new();
        if(my $res = $sf->find_user($id, $server)) {
            try {
                $coll->save({
                    _id => sprintf('%d-%s', $id, $res),
                    user_id     => $id,
                    user_name   => $res,
                    server      => $server,
                }, { safe => 1 });
            };
            return $res;
        }
        return undef;
    }
}

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    warn __PACKAGE__, ': process', "\n";

    return $res unless($res->{complete});

    if(scalar(@{$res->{player}->{statistics}->{teamkill}->{log}}) > 0) {
        foreach my $entry (@{$res->{player}->{statistics}->{teamkill}->{log}}) {
            if(my $name = $self->find_user($entry->{targetID}, $res->{player}->{server})) {
                my $vid = $res->{vehicles_hash_name}->{$name}->{id};
                $res->{player}->{statistics}->{teamkill}->{hash}->{$vid} = $entry;
            }
        }
    }
    return $res;
};

no Moose::Role;
1;
