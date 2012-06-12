package WR::Controller::Replays::Rate;
use Mojo::Base 'WR::Controller';
use boolean;
use Data::Dumper;

sub has_rated {
    my $self = shift;
    my $r = $self->session->{rater};

    if(!$self->session->{rater}) {
        my $id = $self->db('wot-replays')->get_collection('track.rating')->insert({
            rated => [],
        });
        $self->session->{rater} = $id->to_string;
        $r = $id;
    } 

    if(my $v = $self->db('wot-replays')->get_collection('track.rating')->find_one({ 
        _id => bless({ value => $r }, 'MongoDB::OID'),
        rated => $self->stash('req_replay')->{_id},
    })) {
        return 1;
    } else {
        $self->db('wot-replays')->get_collection('track.rating')->update({ _id => bless({ value => $r }, 'MongoDB::OID') }, { '$push' => { 'rated' => $self->stash('req_replay')->{_id} } }, { upsert => 1 });
        return 0;
    }
}

sub rate_up {
    my $self = shift;
    my $c    = $self->stash('req_replay')->{site}->{like} || 0;

    if($self->has_rated) {
        $self->render(json => { ok => 1, c => $c, sudah => 1 });
    } else {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.like' => 1 } });
        $self->render(json => { ok => 1, c => $c + 1, baru => 1 });
    }
}

1;
