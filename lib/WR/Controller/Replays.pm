package WR::Controller::Replays;
use Mojo::Base 'WR::Controller';
use boolean;
use WR::Parser;
use WR::Query;
use FileHandle;
use Mojo::JSON;
use JSON::XS;

sub bridge {
    my $self = shift;
    my $replay_id = $self->stash('replay_id');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $replay_id })) {
        unless($replay->{site}->{visible}) {
            if($self->is_user_authenticated) {
                my $uid = $self->current_user->{_id}->to_string();
                my $uplid = (defined($replay->{site}->{uploaded_by})) ? $replay->{site}->{uploaded_by}->to_string : undef;

                if($uid eq $uplid) {
                    $self->stash(req_replay => WR::Query->fuck_tt($replay));
                    return 1;
                } else {
                    $self->respond(stash => { page => { title => 'Not Found' } }, template => 'replay/notfound') and return 0;
                }
            } else {
                $self->respond(stash => { page => { title => 'Not Found' } }, template => 'replay/notfound') and return 0;
            }
        }
        $self->stash(req_replay => WR::Query->fuck_tt($replay));
        return 1;
    } else {
        $self->respond(stash => { page => { title => 'Not Found' } }, template => 'replay/notfound') and return 0;
    }
}

sub desc {
    my $self = shift;
    
    if($self->stash('req_replay')->{site}->{uploaded_by}->to_string eq $self->current_user->{_id}->to_string) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$set' => { 'site.description' => $self->req->param('desc') }});
    }
    $self->redirect_to(sprintf('/replay/%s/', $self->stash('req_replay')->{_id}));
}

sub get_replays {
    my $self = shift;
    my %args = (@_);

    my $query = $args{'query'} if($args{'query'});
    my $cursor = $self->db('wot-replays')->get_collection('replays')->find($query);

    $cursor->limit($args{'limit'}) if(defined($args{'limit'}));
    $cursor->skip($args{'offset'}) if(defined($args{'offset'}));
    $cursor->sort($args{'sort'}) if(defined($args{'sort'}));

    return [ map { WR::Query->fuck_tt($_) } $cursor->all() ];
}

sub browse {
    my $self = shift;
    my $filter = {};
    my $skey = $self->req->param('skey') || 'browsefilter';

    # restore the original filter if it's the initial load (e.g. non-ajax)
    if($self->session->{$skey} && !$self->req->is_xhr) {
        $filter = $self->session->{$skey};
    } else {
        for(qw/map vehicle player playerpov playerinv vehiclepov vehicleinv server/) {
            $filter->{$_} = $self->req->param($_) if($self->req->param($_));
        }

        my $complete = $self->req->param('complete');
        my $survived = $self->req->param('survived');

        $filter->{complete} = 1 if(defined($complete) && $complete == 1);
        $filter->{survived} = 1 if(defined($survived) && $survived == 1);
        $self->session($skey => $filter);
    }

    my $sort = { 'site.uploaded_at' => -1 };

    my $query = $self->wr_query(
        sort => $sort,
        perpage => 15,
        filter => $filter,
        );
            
    my $p    = $self->req->param('p') || 1;
    my $template = ($self->req->is_xhr) ? 'browse/ajax' : 'browse/index';

    $self->respond(
        template => $template,
        stash => {
            page => {
                title   =>  'Browse',
            },
            replays => $query->page($p),
            filter  => $filter,
            maxp    => $query->maxp,
            p       => $p,
        }
    );
}

1;
