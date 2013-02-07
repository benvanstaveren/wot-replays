package WR::Role::Process::ResolveServer;
use Moose::Role;
use WR::ServerFinder;
use Try::Tiny qw/catch try/;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;
    my $coll = $self->db->get_collection('cache.server_finder');

    if(my $r = $coll->find_one({ _id => sprintf('%d-%s', $res->{player}->{account_id}, $res->{player}->{name}) })) {
        $res->{player}->{server} = $r->{server};
    } else {
        my $sf = WR::ServerFinder->new();
        if(my $server_res = $sf->find_server($res->{player}->{account_id}, $res->{player}->{name})) {
            try {
                $coll->save({
                    _id => sprintf('%d-%s', $res->{player}->{account_id}, $res->{player}->{name}),
                    user_id     => $res->{player}->{account_id},
                    user_name   => $res->{player}->{name},
                    server      => $server_res,
                }, { safe => 1 });
            };
            $res->{player}->{server} = $server_res;
        } else {
            $res->{player}->{server} = 'unknown';
            return $res; # we're done here
        }
    }

    return $res;
};

no Moose::Role;
1;
