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

    $self->render_later;

    if(defined($self->stash('filter_opts')->{async})) {
        $self->stash('filter_opts')->{base_query}->($self, sub {
            my $result = shift;

            # apply the default_filter from our context if we have it
            if(defined($self->stash('context.filter'))) {
                foreach my $field (keys(%{$self->stash('context.filter')})) {
                    $result->{$field} = $self->stash('context.filter')->{$field};
                }
            }
            $self->_real_browse($result);
        });
    } else {
        if(defined($self->stash('filter_opts')->{base_query})) {
            my $result = $self->stash('filter_opts')->{base_query}->($self);
            if(defined($self->stash('context.filter'))) {
                foreach my $field (keys(%{$self->stash('context.filter')})) {
                    $result->{$field} = $self->stash('context.filter')->{$field};
                }
            }
            $self->_real_browse($result);
        } else {
            $self->_real_browse((defined($self->stash('context.filter'))) ? $self->stash('context.filter') : {});
        }
    }
}

sub _real_browse {
    my $self    = shift;
    my $base_q  = shift;

    if(defined($self->stash('initialize_with'))) {
        my $delay = Mojo::IOLoop->delay(sub {
            $self->_really_real_browse($base_q);
        });
        foreach my $init (@{$self->stash('initialize_with')}) {
            $self->$init($delay->begin(0));
        }
    } else {
        return $self->_really_real_browse($base_q);
    }
}

sub _really_real_browse {
    my $self = shift;
    my $base_q = shift;
    my $filter = {};
    my $perpage = 10;
    my $sorting = {
        upload      => { 'site.uploaded_at'         => -1 },
        matchtime   => { 'game.started'             => -1 },
        xp          => { 'stats.originalXP'         => -1 },
        credits     => { 'stats.originalCredits'    => -1 },
        damage      => { 'stats.damageDealt'        => -1 },
        likes       => { 'site.likes'               => -1 },
        downloads   => { 'site.downloads'           => -1 },
        scouted     => { 'stats.damageAssistedRadio' => -1 },
        battlelevel => { 'game.battle_level'        => -1 },
        };
    my $query_add = undef;

    # yank all the settings out into filter
    my $filterlist = [ split('/', $self->stash('filter') || '') ];

    # if we're logged in and have a setting...
    $perpage = $self->usetting('replay.list.perpage') if($self->is_user_authenticated && defined($self->usetting('replay.list.perpage')));

    while(my $i = shift(@$filterlist)) {
        $filter->{$i} = shift(@$filterlist);
    }

    $self->stash('browse_filter_raw' => $filter); 
    $self->debug('base_q isa: ', ref($base_q));

    if(my $inc = delete($base_q->{_inc})) {
        foreach my $i (@$inc) {
            $filter->{$i} = delete($base_q->{$i});
        }
        delete($base_q->{_inc});
        $query_add = $base_q;
    } else {
        foreach my $k (keys(%$base_q)) {
            $filter->{$k} = $base_q->{$k};
        }
    }

    if(my $strip = delete($base_q->{_strip})) {
        foreach my $i (@$strip) {
            delete($filter->{i});
        }
    }

    if(defined($self->stash('filter_opts')->{filter_root})) {
        $self->stash(filter_root => $self->stash('filter_opts')->{filter_root}->($self));
    }

    my $tier_min = $filter->{tmi} || 1;
    my $tier_max = $filter->{tma} || 10;
    my $sort = $sorting->{$filter->{sr} || 'upload'};

    my $start = [ gettimeofday ];
    my $query = $self->wr_query(
        sort    => $sort,
        perpage => $perpage,
        filter  => $filter,
        add     => $query_add,
        panel   => 1,
        );
           
    $filter->{p} ||= 1;
    my $p = $filter->{p};

    $query->page($p => sub {
        my ($q, $replays) = (@_);
        my $maxp    = $query->maxp;

        $replays ||= [];

        $self->respond(
            template => 'browse/index',
            stash => {
                replays => $replays,
                filter  => $filter,
                maxp    => $maxp,
                p       => $p,
                query   => $query->_query,
                query_sort => $sort,
                timing_query => tv_interval($start, [ gettimeofday ]),
            }
        );
    });
}

1;
