package WR::App::Controller::Replays;
use Mojo::Base 'WR::App::Controller';

use boolean;
use WR::Query;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

sub hunt_replay {
    my $self = shift;
    my $id   = shift;

    if(my $r = $self->model('wot-replays.replays')->find_one({ _id => $id })) {
        return $r;
    } else {
        foreach my $v (@{$self->stash('config')->{wot}->{history}}) {
            if(my $r = $self->model(sprintf('wot-replays.replays.%s', $v))->find_one({ _id => $id })) {
                return $r;
            }
        }
    }
    return undef;
}

sub bridge {
    my $self = shift;
    my $replay_id = bless({ value => $self->stash('replay_id') }, 'MongoDB::OID');

    if($replay_id =~ /\d+-\w+-\d+/) {
        # old replay format
        $self->redirect_to('/') and return 0;
    }

    my $start = [ gettimeofday ];



    if(my $replay = $self->hunt_replay($replay_id)) {
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
        $self->stash('timing_query'  => tv_interval($start, [ gettimeofday ]));
        return 1;
    } else {
        $self->respond(stash => { page => { title => 'Not Found' } }, template => 'replay/notfound') and return 0;
    }
}

sub desc {
    my $self = shift;
    
    if($self->stash('req_replay')->{player}->{name} eq $self->current_user->{player}->{name} && $self->stash('req_replay')->{player}->{server} eq $self->current_user->{player}->{server}) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$set' => { 'site.description' => $self->req->param('desc') }});
        $self->clear_replay_page($self->stash('req_replay')->{_id}->to_string);
    }
    $self->redirect_to(sprintf('/replay/%s.html', $self->stash('req_replay')->{_id}->to_string));
}

sub browse {
    my $self = shift;
    my $filter = {};
    my $skey = sprintf('filter_%s', $self->stash('pageid'));
    my $perpage = $self->req->param('perpage') || 15;
    my $sorting = {
        upload      => { 'site.uploaded_at'         => -1 },
        matchtime   => { 'game.time'                => -1 },
        xp          => { 'statistics.xp_base'       => -1 },
        credits     => { 'statistics.credits_base'  => -1 },
        damage      => { 'statistics.damageDealt'   => -1 },
        likes       => { 'site.like'                => -1 },
        downloads   => { 'site.downloads'           => -1 },
        };

    if($self->req->param('playerpov') == 1 && $self->req->param('playerlist') == 1) {
        return $self->browse_player;
    }

    # restore the original filter if it's the initial load (e.g. non-ajax)
    if($self->session->{$skey} && !$self->req->is_xhr) {
        $filter = $self->session->{$skey};
    } else {
        for(qw/map vehicle player playerpov playerinv vehiclepov vehicleinv server matchmode matchtype/) {
            $filter->{$_} = $self->req->param($_) if($self->req->param($_));
        }
        my $complete = $self->req->param('complete');
        my $survived = $self->req->param('survived');
        my $sort = $self->req->param('sort') || 'upload';
        my $tier_min = $self->req->param('tier_min') || 1;
        my $tier_max = $self->req->param('tier_max') || 10;

        if($self->is_user_authenticated && $self->current_user->{settings}->{hide_incomplete} == 1)  {
            # show them
            delete($filter->{complete});
        } else {
            $filter->{complete} = 1; 
        }

        $filter->{complete} = 1 if(defined($complete) && $complete == 1);
        $filter->{survived} = 1 if(defined($survived) && $survived == 1);
        $filter->{sort} = $sort;
        $filter->{tier_min} = $tier_min;
        $filter->{tier_max} = $tier_max;
        $self->session($skey => $filter);
    }

    # fix this, because we want it to keep the same setting as it did in the session
    if($self->stash('req_host') ne 'www') {
        $filter->{server} = $self->stash('req_host');
    }

    my $sort = $sorting->{$filter->{sort} || 'upload'};

    my $start = [ gettimeofday ];
    my $query = $self->wr_query(
        sort => $sort,
        perpage => $perpage,
        filter => $filter,
        );
            
    my $p    = $self->req->param('p') || 1;

    $self->stash('query' => {
        query   => $query->_query,
        explain => $query->exec->explain,
    });

    my $replays = $query->page($p);
    my $maxp    = $query->maxp;

    $self->stash('timing_query'  => tv_interval($start, [ gettimeofday ]));

    if($self->stash('format') eq 'json') {
        $self->render(json => {
            replays => [ map { $query->fuck_mojo_json($_) } @$replays ],
            filter  => $filter,
            maxp    => $maxp,
            p       => $p,
        });
    } else {
        my $template = ($self->req->is_xhr) ? 'browse/ajax' : 'browse/index';
        $self->respond(
            template => $template,
            stash => {
                page => {
                    title   =>  'Home',
                },
                replays => $replays,
                filter  => $filter,
                maxp    => $maxp,
                p       => $p,
            }
        );
    }
}

1;
