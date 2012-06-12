package WR::Util;
use strict;
use warnings;
use WR::ServerFinder;

sub server_finder {
    my $self = shift;
    my $id   = shift;
    my $name = shift;
    my $coll = $self->db('wot-replays')->get_collection('cache.server_finder');

    if(my $r = $coll->find_one({ _id => sprintf('%d-%s', $id, $name) })) {
        return $r->{server};
    } else {
        my $sf = WR::ServerFinder->new();
        if(my $res = $sf->find_server($id, $name)) {
            $coll->save({
                _id => sprintf('%d-%s', $id, $name),
                user_id     => $id,
                user_name   => $name,
                server      => $res,
            });
            return $res;
        } else {
            return 'unknown';
        }
    }
}

sub user_finder {
    my $self = shift;
    my $id   = shift;
    my $server = shift;

    my $coll = $self->db('wot-replays')->get_collection('cache.server_finder');

    if(my $r = $coll->find_one({ user_id => $id, server => $server })) {
        return $r->{user_name};
    } else {
        my $sf = WR::ServerFinder->new();
        if(my $res = $sf->find_user($id, $server)) {
            $coll->save({
                _id => sprintf('%d-%s', $id, $res),
                user_id     => $id,
                user_name   => $res,
                server      => $server,
            });
            return $res;
        }
        return undef;
    }
}

sub award_mastery {
    my $self = shift;
    my $player = shift;
    my $vehicle = shift;
    my $mastery = shift;

    if(my $rec = $self->db('wot-replays')->get_collection('track.mastery')->find_one({ _id => sprintf('%s_%s', $player, $vehicle) })) {
        if($mastery > $rec->{value}) {
            $self->db('wot-replays')->get_collection('track.mastery')->update(
                {
                    _id => sprintf('%s_%s', $player, $vehicle)
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
        $self->db('wot-replays')->get_collection('track.mastery')->save({ _id => sprintf('%s_%s', $player, $vehicle), 'value' => $mastery });
        return $mastery;
    }
}

1;
