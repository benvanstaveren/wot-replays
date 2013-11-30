package WR::App::Controller::Replays;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use WR::Query;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

sub desc {
    my $self = shift;

    $self->render_later;
    if($self->is_user_authenticated) {
        $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) } => sub {
            my ($c, $e, $d) = (@_);

            if(defined($d)) {
                if($self->is_own_replay($d)) {
                    $self->model('wot-replays.replays')->update({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) }, { '$set' => { 'site.description' => $self->req->param('desc') }} => sub {
                        my ($c, $e, $d) = (@_);

                        $self->render(json => { ok => 1 });
                    });
                } else {
                    $self->render(json => { ok => 0, error => 'That replay does not belong to you' });
                }
            } else {
                $self->render(json => { ok => 0, error => 'That replay does not exist' });
            }
        });
    } else {
        $self->render(json => { ok => 0, error => 'You may want to log in first...' });
    }
}

sub browse {
    my $self = shift;
    my $filter = {};
    my $perpage = $self->req->param('perpage') || 15;
    my $sorting = {
        upload      => { 'site.uploaded_at'         => -1 },
        matchtime   => { 'game.started'             => -1 },
        xp          => { 'stats.originalXP'         => -1 },
        credits     => { 'stats.originalCredits'    => -1 },
        damage      => { 'stats.damageDealt'        => -1 },
        likes       => { 'site.like'                => -1 },
        downloads   => { 'site.downloads'           => -1 },
        };

    # yank all the settings out into filter
    my $filterlist = [ split('/', $self->stash('filter')) ];
    while(my $i = shift(@$filterlist)) {
        $filter->{$i} = shift(@$filterlist);
    }

    $self->stash('browse_filter_raw' => $filter);

    $self->render_later;

    my $tier_min = $filter->{tier_min} || 1;
    my $tier_max = $filter->{tier_max} || 10;
    my $sort = $sorting->{$filter->{sort} || 'upload'};

    my $start = [ gettimeofday ];
    my $query = $self->wr_query(
        sort => $sort,
        perpage => $perpage,
        filter => $filter,
        );
            
    my $p = $filter->{p} || 1;
    $query->page($p => sub {
        my $replays = shift || [];
        my $maxp    = $query->maxp;

        $self->stash('timing_query'  => tv_interval($start, [ gettimeofday ]));

        my $template = 'browse/index';
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
    });
}

1;
