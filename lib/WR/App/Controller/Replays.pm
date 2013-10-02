package WR::App::Controller::Replays;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use WR::Query;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

sub desc {
    my $self = shift;

    $self->redirect_to(sprintf('/replay/%s.html', $self->stash('replay_id'))) unless($self->is_user_authenticated);
    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) } => sub {
        my ($c, $e, $d) = (@_);

        if(defined($d) && $d->{game}->{server} eq $self->current_user->{player_server} && $d->{game}->{recorder}->{name} eq $self->current_user->{player_name}) {
            $self->model('wot-replays.replays')->update({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) }, { '$set' => { 'site.description' => $self->req->param('desc') }} => sub {
                my ($c, $e, $d) = (@_);
                $self->redirect_to(sprintf('/replay/%s.html', $self->stash('replay_id')));
            });
        } else {
            $self->redirect_to(sprintf('/replay/%s.html', $self->stash('replay_id')));
        }
    });
}

sub browse {
    my $self = shift;
    my $filter = {};
    my $skey = sprintf('filter_%s', $self->stash('pageid'));
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

    return $self->browse_player if($self->req->param('playerpov') == 1 && $self->req->param('playerlist') == 1);

    $self->render_later;

    # restore the original filter if it's the initial load (e.g. non-ajax)
    if($self->session->{$skey} && !$self->req->is_xhr) {
        $filter = $self->session->{$skey};
    } else {
        for(qw/map vehicle player playerpov playerinv vehiclepov vehicleinv server matchmode matchtype/) {
            $filter->{$_} = $self->req->param($_) if($self->req->param($_));
        }
        my $survived = $self->req->param('survived');
        my $sort = $self->req->param('sort') || 'upload';
        my $tier_min = $self->req->param('tier_min') || 1;
        my $tier_max = $self->req->param('tier_max') || 10;

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
    $query->page($p => sub {
        my $replays = shift || [];
        my $maxp    = $query->maxp;

        $self->stash('timing_query'  => tv_interval($start, [ gettimeofday ]));

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
    });
}

1;
