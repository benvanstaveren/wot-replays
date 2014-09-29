package WR::Web::Site::Controller::Replays::Rate;
use Mojo::Base 'WR::Web::Site::Controller';
use Data::Dumper;
use Mango::BSON;

sub init_rater {
    my $self = shift;
    my $replay = shift;
    my $cb   = shift;
    
    $self->model('wot-replays.track.rating')->insert({ rated => [] } => sub {
        my ($c, $e, $oid) = (@_);

        $self->session(rater => $oid . '');
        $self->find_has_rated($replay, $oid, $cb);
    });
}

sub find_has_rated {
    my $self = shift;
    my $replay = shift;
    my $r    = shift;
    my $cb   = shift;

    $self->model('wot-replays.track.rating')->find_one({
        _id => $r, rated => $replay->{_id}
    } => sub {
        my ($c, $e, $d) = (@_);

        # if we have not rated yet, we actually update it as well before ticking off the 
        # callback
        if(defined($d)) {
            $cb->(1);
        } else {
            $self->model('wot-replays.track.rating')->update({ _id => $r }, { '$push' => { 'rated' => $replay->{_id} } }, { upsert => 1 } => sub {
                my ($c, $e, $d) = (@_);
                $cb->(0);
            });
        }
    });
}

sub has_rated {
    my $self = shift;
    my $replay = shift;
    my $r    = $self->session->{rater};
    my $cb   = shift;

    if(!$self->session('rater')) {
        $self->init_rater($replay => $cb);
    }  else {
        $self->find_has_rated($replay => $r => $cb);
    }
}

sub rate_up {
    my $self = shift;

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) } => sub {
        my ($coll, $e, $doc) = (@_);
        if($doc) {
            my $c = $doc->{site}->{like} || 0;
            $self->has_rated($doc => sub {
                my $hr = shift;
                if($hr == 1) {
                    $self->render(json => { ok => 1, c => $c, sudah => 1 });
                } else {
                    $self->model('wot-replays.replays')->update({ _id => $doc->{_id} }, { '$inc' => { 'site.like' => 1 } } => sub {
                        my ($col, $e, $d) = (@_);
                        $self->render(json => { ok => 1, c => $c + 1, baru => 1 });
                    });
                }
            });
        } else {
            $self->render(json => { ok => 0, error => 'Uh, missing replay?' });
        }
    });
}

1;
