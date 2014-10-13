package WR::Web::Site::Controller::Replays::View;
use Mojo::Base 'WR::Web::Site::Controller';
use Mango::BSON;
use WR::Query;
use WR::Res::Achievements;
use WR::Provider::Mapgrid;
use File::Slurp qw/read_file/;
use Time::HiRes qw/gettimeofday tv_interval/;
use JSON::XS;

sub load_replay {
    my $self = shift;
    my $cb   = shift;

    $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) } => $cb);
}

sub is_allowed_to_view {
    my $self   = shift;
    my $replay = shift;

    return 1 if($replay->{site}->{visible});
    return 1 if($replay->{site}->{privacy} == 1); # anyone can see these as long as they have a link

    # the next ones require users to be logged in
    return 0 unless $self->is_user_authenticated;

    if($replay->{site}->{privacy} == 2) {
        $self->debug('privacy: private');
        return 1 if( 
            ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
            ($replay->{game}->{recorder}->{name} eq $self->current_user->{player_name})
        );
        return 1 if($self->req->param('bypass') == 1 && $self->is_the_boss);
        return 0;
    } elsif($replay->{site}->{privacy} == 3) {
        $self->debug('privacy: clan');
        return 0 unless(defined($self->current_user->{clan}));
        return 1 if( 
            ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
            ($replay->{game}->{recorder}->{clan} eq $self->current_user->{clan}->{abbreviation})
        );
        return 1 if($self->req->param('bypass') == 1 && $self->is_the_boss);
        return 0;
    } elsif($replay->{site}->{privacy} == 4) {
        $self->debug('privacy: participants');
        foreach my $player (@{$replay->{involved}->{players}}) {
            $self->debug('check ', $player, ' against ', $self->current_user->{player_name});
            return 1 if(
                ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
                ($player eq $self->current_user->{player_name})
            );
        }
        return 1 if($self->req->param('bypass') == 1 && $self->is_the_boss);
        return 0;
    } elsif($replay->{site}->{privacy} == 5) {
        $self->debug('privacy: team');
        if(!defined($replay->{involved}->{team})) {
            $self->debug('replay has no team list, fixing...');
            my $rteam = $replay->{game}->{recorder}->{team};
            my $t = [];
            foreach my $entry (@{$replay->{roster}}) {
                if($entry->{player}->{team} == $rteam) {
                    push(@$t, $entry->{player}->{name});
                }
            }
            $self->model('wot-replays.replays')->update({ _id => $replay->{_id} }, { '$set' => { 'involved.team' => $t } } => sub {
                $self->redirect_to(sprintf('/replay/%s.html', $replay->{_id} . ''));
            });
            return -1;
        } else {
            foreach my $player (@{$replay->{involved}->{team}}) {
                return 1 if(
                    ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
                    ($player eq $self->current_user->{player_name})
                );
            }
            return 1 if($self->req->param('bypass') == 1 && $self->is_the_boss);
            return 0;
        }
    }
    return 0; # should never get here
}

sub battleviewer {
    my $self = shift;

    $self->render_later;

    $self->load_replay(sub {
        my ($c, $e, $replay) = @_;

        if(defined($replay)) {
            # construct packet url
            if($self->is_allowed_to_view($replay)) {
                my $packet_url = sprintf('%s/%s', $self->stash('config')->{urls}->{packets}, $replay->{packets});
                $self->respond(template => 'replay/view/battleviewer', stash => {
                    packet_url  => $packet_url,
                    replay      => $replay,
                });
            } else {
                $self->respond(template => 'replay/view/denied', stash => { page => { title => $self->loc('page.replay.denied.title') }});
            }
        } else {
            $self->respond(template => 'replay/view/nopackets', stash => { page => { title => 'Battle Viewer' }});
        }
    });
}

sub heatmap {
    my $self = shift;

    $self->render_later;

    $self->load_replay(sub {
        my ($c, $e, $replay) = @_;

        if(defined($replay)) {
            unless($self->is_allowed_to_view($replay)) {
                $self->respond(template => 'replay/view/denied', stash => { page => { title => $self->loc('page.replay.denied.title') }});
                return;
            }

            # generate the data set
            my $mapgrid = WR::Provider::Mapgrid->new(
                width       => 768,
                height      => 768,
                bounds      => $self->map_boundingbox($replay),
            );
            my $max = 0;
            my $set = []; 

            foreach my $x (keys(%{$replay->{heatmap}})) {
                foreach my $y (keys(%{$replay->{heatmap}->{$x}})) {
                    # somewhat normalize these things by multiplying by 10 - e.g. 0.2 -> 2, 0.5 -> 5, 123.999 -> 1239 
                    my $val = sprintf('%.0f', $replay->{heatmap}->{$x}->{$y} * 10);
                    $max = $val if($val > $max);
                    my $coord = $mapgrid->game_to_map_coord([ $x, 0, $y ]);
                    push(@$set, {
                        x => int($coord->{x}),
                        y => int($coord->{y}),
                        count => $val,
                    });
                }
            }

            $self->respond(template => 'replay/view/heatmap', stash => {
                replay      => $replay,
                dataset     => { max => $max, data => $set },
            });
        } else {
            $self->respond(template => 'replay/view/nodata', stash => { page => { title => 'Battle Heatmap' }});
        }
    });
}

sub get_comparison {
    my $self = shift;
    my $p    = shift;
    my $cb   = shift;

    my $pp   = 10;
    my $offset = (($p-1) * $pp);
    my $oid = Mango::BSON::bson_oid($self->stash('replay_id'));

    $self->load_replay(sub {
        my ($c, $e, $replay) = @_;
        my $vehicle = $self->get_recorder_vehicle($replay);

        my $query = {
            _id => { '$nin' => [ $oid ] },
            'roster.vehicle.ident' => $vehicle->{ident},
            'game.map' => $replay->{game}->{map},
        };

        my $cursor = $self->model('wot-replays.replays')->find($query);
        $cursor->count(sub {
            my ($cursor, $e, $total) = (@_);
            my $maxp  = int($total/$pp);
            $maxp++ if($maxp * $pp < $total);
            $cursor->sort({ 'site.uploaded_at' => -1 });
            $cursor->skip($offset);
            $cursor->limit($pp);

            my $result = [];

            $cursor->all(sub {
                my ($cursor, $e, $docs) = (@_);

                foreach my $r (@$docs) {
                    my $d = {
                        url     => sprintf('/replay/%s.html', $r->{_id} . ''),
                        player  => $r->{game}->{recorder}->{name},
                        mode    => $r->{game}->{type},
                    };
                    for(qw/kills damaged spotted damageDealt originalCredits originalXP/) {
                        $d->{$_} = {
                            this => $replay->{stats}->{$_} + 0,
                            that => $r->{stats}->{$_} + 0,
                            flag => ($replay->{stats}->{$_} + 0 > $r->{stats}->{$_} + 0) 
                                ? '>'
                                : ($replay->{stats}->{$_} + 0 < $r->{stats}->{$_} + 0)
                                    ? '<'
                                    : '='
                        }
                    }

                    my $this_acc = ($replay->{stats}->{shots} > 0 && $replay->{stats}->{hits} > 0) 
                        ? sprintf('%.0f', (100/($replay->{stats}->{shots}/$replay->{stats}->{hits})))
                        : 0;
                    my $that_acc = ($r->{stats}->{shots} > 0 && $r->{stats}->{hits} > 0) 
                        ? sprintf('%.0f', (100/($r->{stats}->{shots}/$r->{stats}->{hits})))
                        : 0;

                    $d->{accuracy} = {
                        this => $this_acc,
                        that => $that_acc,
                        flag => ($this_acc > $that_acc)
                            ? '>'
                            : ($this_acc < $that_acc) 
                                ? '<'
                                : '='
                    };
                    my $hc = 0;
                    foreach my $v (values(%$d)) {
                        next unless(ref($v) eq 'HASH');
                        $hc += 1 if($v->{flag} eq '>');
                        $hc += 0 if($v->{flag} eq '=');
                        $hc -= 1 if($v->{flag} eq '=');
                    }
                    $d->{rating} = $hc;
                    push(@$result, $d);
                }
                $cb->({
                    p => $p,
                    maxp => $maxp,
                    results => $result,
                    total => $total,
                });
            });
        });
    });
}

sub comparison {
    my $self = shift;
    my $p    = $self->req->param('p') || 1;

    $self->render_later;
    $self->get_comparison($p => sub {
        my $r = shift;
        $self->respond(template => 'replay/view/comparison', stash => $r);
    });
}

sub delcomment {
    my $self = shift;
    my $comment_id = $self->stash('comment_id');

    $self->load_replay(sub {
        my ($c, $e, $replay) = (@_);

        if(defined($replay)) {
            if($self->is_user_authenticated && ($self->is_the_boss || $self->has_role('comment_moderator'))) {
                $self->model('wot-replays.replays')->update({ _id => $replay->{_id} }, {
                    '$pull' => { 'site.comments' => { id => $comment_id } },
                } => sub {
                    my ($c, $e, $d) = (@_);
                    $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
                });
            } else {
                $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
            }
        } else {
            $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
        } 
    });
}

sub addcomment {
    my $self = shift;

    $self->load_replay(sub {
        my ($c, $e, $replay) = (@_);

        if(defined($replay)) {
            unless($self->is_allowed_to_view($replay)) {
                $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
            } else {
                if($self->is_user_authenticated) {
                    my $comment_id = sprintf('c%s', Mango::BSON::bson_oid . '');
                    my $text = $self->req->param('comment');
                    if(defined($text) && length($text) > 0) {
                        my $comment    = {
                            id      => $comment_id,
                            author  => {
                                name    => $self->current_user->{player_name},
                                server  => $self->current_user->{player_server},
                                clan    => $self->current_user_clan,
                            },
                            posted      => Mango::BSON::bson_time,
                            text        => $self->req->param('comment'),
                        };
                        $self->model('wot-replays.replays')->update({ _id => $replay->{_id} }, {
                            '$push' => { 'site.comments' => $comment },
                        } => sub {
                            my ($c, $e, $d) = (@_);

                            if(defined($e)) {
                                $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
                            } else {
                                $self->redirect_to(sprintf('/replay/%s.html#comments-%s', $replay->{_id} . '', $comment_id));
                            }
                        });
                    } else {
                        $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
                    }
                } else {
                    $self->redirect_to(sprintf('/replay/%s.html#comments', $replay->{_id} . ''));
                }
            }
        } else {
            $self->redirect_to('/');
        }
    });
}

sub tdebug {
    my $self = shift;
    $self->debug('[', sprintf('%d.%d', gettimeofday), ']: ', join(' ', @_));
}

sub view {
    my $self  = shift;
    my $start = [ gettimeofday ];
    my $desc;

    $self->render_later;
    $self->stash('cachereplay' => 1);

    $self->tdebug('view top'); 
    $self->load_replay(sub {
        my ($c, $e, $replay) = (@_);

        $self->tdebug('load_replay cb'); 

        if(defined($replay)) {
            $self->tdebug('is_allowed_to_view check start');
            my $r = $self->is_allowed_to_view($replay);
            $self->tdebug('is_allowed_to_view check end');
            if($r == 0) {
                $self->respond(template => 'replay/view/denied', stash => { page => { title => $self->loc('page.replay.denied.title') }});
                return;
            } elsif($r == -1 ) {
                return;
            } else {
                $self->actual_view_replay($replay, $start);
            }
        } else {
            $self->redirect_to('/');
        }
    });
}

sub packets {
    my $self = shift;
    my $id   = $self->stash('replay_id');

    my $packet_base = sprintf('%s/%s.json', $self->hashbucket($id), $id);
    my $packet_uri  = sprintf('/packets/%s', $packet_base);

    # nginx trickery ahead
    $self->res->headers->header('X-Accel-Redirect' => $packet_uri);
    $self->res->headers->content_type('application/json');
    $self->render(text => 'x-accel-redirect');
}

sub actual_view_replay {
    my $self = shift;
    my $replay = shift;
    my $start = shift;

    $self->tdebug('actual_view_replay top');

    my $title = sprintf('%s - %s - %s (%s)',
        $replay->{game}->{recorder}->{name},
        $self->loc($self->get_recorder_vehicle($replay)->{vehicle}->{i18n}),
        $self->loc($self->map_name($replay)),
        $self->loc(sprintf('gametype.%s', $replay->{game}->{type}))
        );

    my $description = sprintf('This is a replay of a %s match fought by %s, using the %s vehicle, on map %s', 
        lc($self->loc(sprintf('gametype.%s', $replay->{game}->{type}))),
        $replay->{game}->{recorder}->{name}, 
        $self->loc($self->get_recorder_vehicle($replay)->{vehicle}->{i18n}),
        $self->loc($self->map_name($replay)),
        );

    my $playerteam = $replay->{game}->{recorder}->{team} - 1;

    if($playerteam == 0) {
        # swap teams 0/1
        $replay->{teams} = [ $replay->{teams}->[0], $replay->{teams}->[1] ];
        for(qw/damage xp kills/) {
            $replay->{teams_sorted}->{$_} = [ $replay->{teams_sorted}->{$_}->[0], $replay->{teams_sorted}->{$_}->[1] ];
        }
    } else {
        # swap teams 1 / 0
        $replay->{teams} = [ $replay->{teams}->[1], $replay->{teams}->[0] ];
        for(qw/damage xp kills/) {
            $replay->{teams_sorted}->{$_} = [ $replay->{teams_sorted}->{$_}->[1], $replay->{teams_sorted}->{$_}->[0] ];
        }
    }

    my $dossier_popups = {};
    my $other_awards = [];
    my $achievements = WR::Res::Achievements->new();

    my $ah = { map { $_ => 1 } @{$replay->{stats}->{achievements}} };

    foreach my $e (@{$replay->{stats}->{dossierPopUps}}) {
        $dossier_popups->{$e->[0]} = $e->[1]; # id, count
        next if(defined($ah->{$e->[0]})); # if they were given in battle, keep them there

        if($achievements->is_class($e->[0])) {
            # class achievements get the whole medalKay1..4 etc. bit so add a class suffix, and no count
            push(@$other_awards, {
                class_suffix => $e->[1],
                count => undef,
                type => $e->[0],
            });
        } elsif($achievements->is_single($e->[0])) {
            push(@$other_awards, {
                class_suffix => undef,
                count => undef,
                type => $e->[0],
            });
        } elsif($achievements->is_repeatable($e->[0])) {
            push(@$other_awards, {
                class_suffix => undef,
                count => $e->[1],
                type => $e->[0],
            });
        }
    }

    # and here one thing we need to do is generate the platoons and their counts
    my $idx = [0, 0];
    my $pl_indexes = {};
    my $pl_members = {}; 

    foreach my $v (@{$replay->{roster}}) {
        my $team = $v->{player}->{team};
        my $pbid = $v->{player}->{prebattleID};

        next unless($pbid > 0);

        unless(defined($pl_indexes->{$pbid})) {
            $pl_indexes->{$pbid} = ++$idx->[$team-1];
        }

        $pl_members->{$v->{player}->{name}} = $pl_indexes->{$pbid};
    }

    $self->tdebug('actual_view_replay pre-render delay');

    my $delay = Mojo::IOLoop->delay(sub {
        $replay->{site}->{views} += 1;  # little holdover here...
        $self->tdebug('actual_view_replay render delay cb');

        $self->respond(
            stash => {
                pageid => 'replay', # really? yah really
                replay => $replay,
                page   => {
                    title => $title,
                    description => $description,
                },
                other_awards => $other_awards,
                platoons => $pl_members,
                hashbucket => $self->hashbucket($replay->{_id} . ''), # easier to handle some things 
                include_battleviewer => 1,
                timing_view => tv_interval($start, [ gettimeofday ]),
            }, 
            template => 'replay/view/index',
        );
        $self->tdebug('actual_view_replay respond end');
    });

    $self->tdebug('actual_view_replay ping thunderpush and update stats start');
    my $tpe = $delay->begin(0);
    $self->app->thunderpush->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.view', data => { id => $replay->{_id} . '' } }) => sub { 
        $self->tdebug('thunderpush->send_to_channel cb');
        $tpe->();
    });
    $self->_update_stats_total($replay->{_id}, $delay->begin(0));
    $self->_update_stats_daily($replay->{_id}, $delay->begin(0));
    $self->tdebug('actual_view_replay ping thunderpush and update stats end');
    $self->tdebug('actual_view_replay bottom');
}

sub _update_stats_total {
    my $self = shift;
    my $id   = shift;
    my $end  = shift;
    $self->model('wot-replays.replays')->update({ _id => $id }, { '$inc' => { 'site.views' => 1 }} => sub {
        $self->tdebug('update_stats_total cb');
        $end->();
    });
}

sub _update_stats_daily {
    my $self = shift;
    my $id   = shift;
    my $end  = shift;
    my $now  = DateTime->now(time_zone => 'UTC')->strftime('%Y%m%d');

    $self->model('wot-replays.stats_replay')->update({ replay => $id, date => $now }, { '$inc' => { 'views' => 1 } } => sub {
        $self->tdebug('update_stats_daily cb');
        $end->();
    });
}

1;
