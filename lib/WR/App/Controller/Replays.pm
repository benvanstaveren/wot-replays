package WR::App::Controller::Replays;
use Mojo::Base 'WR::App::Controller';

use boolean;
use WR::Query;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

sub bridge {
    my $self = shift;
    my $replay_id = bless({ value => $self->stash('replay_id') }, 'MongoDB::OID');

    if($replay_id =~ /\d+-\w+-\d+/) {
        # old replay format
        $self->redirect_to('/') and return 0;
    }

    my $start = [ gettimeofday ];

    if(my $replay = $self->model('wot-replays.replays')->find_one({ _id => $replay_id })) {
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
    my $skey = $self->req->param('skey') || sprintf('filter_%s', $self->stash('pageid'));
    my $perpage = $self->req->param('perpage') || 15;
    my $sorting = {
        upload      => { 'site.uploaded_at' => -1 },
        xp          => { 'statistics.xp' => -1 },
        credits     => { 'statistics.credits' => -1 },
        damage      => { 'statistics.damageDealt' => -1 },
        likes       => { 'site.like' => -1 },
        downloads   => { 'site.downloads' => -1 },
        };

    # restore the original filter if it's the initial load (e.g. non-ajax)
    if($self->session->{$skey} && !$self->req->is_xhr) {
        $filter = $self->session->{$skey};
    } else {
        for(qw/map vehicle player playerpov playerinv vehiclepov vehicleinv server matchmode matchtype/) {
            $filter->{$_} = $self->req->param($_) if($self->req->param($_));
        }
        my $complete = $self->req->param('complete');
        my $survived = $self->req->param('survived');
        my $compatible = $self->req->param('compatible');
        my $sort = $self->req->param('sort') || 'upload';

        if($self->is_user_authenticated && $self->current_user->{settings}->{hide_incomplete} == 1)  {
            # show them
            delete($filter->{complete});
        } else {
            $filter->{complete} = 1; 
        }

        $filter->{complete} = 1 if(defined($complete) && $complete == 1);
        $filter->{survived} = 1 if(defined($survived) && $survived == 1);
        $filter->{compatible} = 1 if(defined($compatible) && $compatible == 1);
        $filter->{sort} = $sort;

        $self->session($skey => $filter);
    }

    my $sort = $sorting->{$filter->{sort} || 'upload'};
    $filter->{version} = $self->stash('config')->{wot}->{version} if($filter->{compatible}); 

    my $query = $self->wr_query(
        sort => $sort,
        perpage => $perpage,
        filter => $filter,
        );
            
    my $p    = $self->req->param('p') || 1;

    if($self->stash('format') eq 'json') {
        $self->render(json => {
            replays => [ map { $query->fuck_mojo_json($_) } @{$query->page($p)} ],
            filter  => $filter,
            maxp    => $query->maxp,
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
                replays => $query->page($p),
                filter  => $filter,
                maxp    => $query->maxp,
                p       => $p,
            }
        );
    }
}

1;
