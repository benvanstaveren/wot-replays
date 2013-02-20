package WR::Events;
use Mojo::Base '-base';
use WR::Query;
use DateTime;

has 'server';
has 'db';
has 'now'    => sub { DateTime->now(time_zone => 'UTC')->epoch };

sub events {
    my $self = shift;
    my %args = (
        all => 0,
        @_
        );

    my $query = {
        server       => $self->server,
    };

    my $cursor = $self->db->get_collection('events')->find($query)->sort({ event_starts => -1 });

    $cursor->limit(15) if($args{all} == 0);
    return [ $cursor->all() ];
}

sub event {
    my $self = shift;
    my $id   = shift;

    $id = bless({ value => $id }, 'MongoDB::OID') if(!ref($id));
    if(my $event = $self->db->get_collection('events')->find_one({ _id => $id })) {
        my $query = {};
        foreach my $filter (@{$event->{filter}}) {
            if($filter->{regex}) {
                $query->{$filter->{field}} = $filter->{regex};
            }

            if(defined($query->{'player.name'})) {
                my $pq = delete($query->{'player.name'});
                $query->{'$or'} = [
                    { 'player.name' => $pq },
                    { 'vehicles_a.name' => $pq },
                ];
            }
        }

        $query->{'game.time'} = {
            '$lte' => $event->{event_end},
            '$gte' => $event->{event_start},
        };

        return {
            event => $event,
            cursor => $self->db->get_collection('replays')->find($query),
        };
    } else {
        return undef;
    }
}
       
1;
