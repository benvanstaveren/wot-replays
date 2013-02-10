package WR::Role::Process::ResolveServer;
use Moose::Role;
use WR::ServerFinder;
use Try::Tiny qw/catch try/;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;
    my $coll = $self->db->get_collection('cache.server_finder');
    my $sf   = WR::ServerFinder->new();

    if(my $server = $sf->get_server_by_id($res->{player}->{account_id})) {
        $res->{player}->{server} = $server;
        $coll->save({
            _id => sprintf('%d-%s', $res->{player}->{account_id}, $res->{player}->{name}),
            user_id     => $res->{player}->{account_id},
            user_name   => $res->{player}->{name},
            server      => $server,
            via         => 'get_server_by_id',
        }, { safe => 1 });
    } else {
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
                        via         => 'find_server',
                    }, { safe => 1 });
                };
                $res->{player}->{server} = $server_res;
            } else {
                $res->{player}->{server} = 'unknown';
            }
        }
    }

    # fix em up for the other players as well if we can do it with get_server_by_id 
    foreach my $pid (keys(%{$res->{players}})) {
        my $name = $res->{players}->{$pid}->{name};
        if(my $server = $sf->get_server_by_id($pid + 0)) {
            $coll->save({
                _id => sprintf('%d-%s', $pid + 0, $name),
                user_id     => $pid + 0,
                user_name   => $name,
                server      => $server,
                via         => 'find_server',
            }, { safe => 1 });
        }
    }

    return $res;
};

no Moose::Role;
1;
