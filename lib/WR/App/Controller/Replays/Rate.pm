package WR::App::Controller::Replays::Rate;
use Mojo::Base 'WR::App::Controller';
use Data::Dumper;
use Mango::BSON;

sub init_rater {
    my $self = shift;
    my $cb   = shift;
    
    $self->model('wot-replays.track.rating')->insert({ rated => [] } => sub {
        my ($c, $e, $oid) = (@_);

        $self->session(rater => $oid . '');
        $self->find_has_rated($oid, $cb);
    });
}

sub find_has_rated {
    my $self = shift;
    my $r    = shift;
    my $cb   = shift;

    $self->model('wot-replays.track.rating')->find_one({
        _id => $r, rated => $self->stash('req_replay')->{_id}
    } => sub {
        my ($c, $e, $d) = (@_);

        # if we have not rated yet, we actually update it as well before ticking off the 
        # callback
        if(defined($d)) {
            $cb->(1);
        } else {
            $self->model('wot-replays.track.rating')->update({ _id => $r }, { '$push' => { 'rated' => $self->stash('req_replay')->{_id} } }, { upsert => 1 } => sub {
                my ($c, $e, $d) = (@_);

                $cb->(0);
            });
        }
    });
}

sub has_rated {
    my $self = shift;
    my $r    = $self->session->{rater};
    my $cb   = shift;

    if(!$self->session('rater')) {
        $self->init_rater($cb);
    }  else {
        $self->find_has_rated($cb);
    }
}

sub rate_up {
    my $self = shift;
    my $c    = $self->stash('req_replay')->{site}->{like} || 0;

    $self->render_later;
    $self->has_rated(sub {
        my $hr = shift;

        if($hr == 1) {
            $self->render(json => { ok => 1, c => $c, sudah => 1 });
        } else {
            $self->model('wot-replays.replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.like' => 1 } } => sub {
                my ($col, $e, $d) = (@_);
                $self->render(json => { ok => 1, c => $c + 1, baru => 1 });
            });
        }
    });
}

1;
