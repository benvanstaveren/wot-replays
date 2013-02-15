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

    my $cursor = $self->db->get_collection('events')->find({
        server       => $self->server,
        event_starts => { '$lte' => $self->now },
        event_ends   => { '$gte' => $self->now }
    })->sort({ event_starts => -1 });

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
        }
        return $self->db->get_collection('replays')->find($query); 
    } else {
        return undef;
    }
}
       
1;
