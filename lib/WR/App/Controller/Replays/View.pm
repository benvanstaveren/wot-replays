package WR::App::Controller::Replays::View;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use WR::Query;
use WR::Res::Achievements;
use WR::Provider::Mapgrid;
use File::Slurp qw/read_file/;
use Time::HiRes qw/gettimeofday tv_interval/;
use JSON::XS;
use Text::CSV_XS;
use WR::Mission;

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
        return 1 if( 
            ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
            ($replay->{game}->{recorder}->{name} eq $self->current_user->{player_name})
        );
        return 0;
    } elsif($replay->{site}->{privacy} == 3) {
        return 0 unless(defined($self->current_user->{clan}));
        return 1 if( 
            ($replay->{game}->{server} eq $self->current_user->{player_server}) &&
            ($replay->{game}->{recorder}->{clan} eq $self->current_user->{clan}->{abbreviation})
        );
        return 0;
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
                    page        => { title => 'Battle Viewer' },
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
                page        => { title => 'Battle Heatmap' },
                replay      => $replay,
                dataset     => { max => $max, data => $set },
            });
        } else {
            $self->respond(template => 'replay/view/nodata', stash => { page => { title => 'Battle Heatmap' }});
        }
    });
}

sub stats {
    my $self = shift;

    $self->render_later;
    $self->load_replay(sub {
        my ($c, $e, $r) = (@_);
        $self->render(json => {
            views => $r->{site}->{views} + 0,
            downloads => $r->{site}->{downloads} + 0,
            likes => $r->{site}->{like} + 0,
        });
    });
}

sub incview {
    my $self = shift;

    $self->render_later;
    $self->model('wot-replays.replays')->update({ _id => Mango::BSON::bson_oid($self->stash('replay_id')) }, {
        '$inc' => { 'site.views' => 1 }
    } => sub {
        $self->render(json => { ok => 1 });
    });
}

sub generate_mission_panel {
    my $self    = shift;
    my $replay  = shift;
    my $cb      = shift;
    my $mission_panel = [];

    # if there are no missions then we don't even need to bother and we can just bail out now
    $cb->($mission_panel) and return unless(scalar(keys(%{$replay->{stats}->{questsProgress}})) > 0);

    my $delay   = Mojo::IOLoop->delay(sub {
        $cb->($mission_panel);
    });

    foreach my $mission_id (sort(keys(%{$replay->{stats}->{questsProgress}}))) {
        my $end = $delay->begin;
        $self->model('statterbox.missions')->find_one({ _id => $mission_id } => sub {
            my ($coll, $err, $doc) = (@_);

            if(defined($doc)) {
                my $mission = WR::Mission->new(mission => $doc, result => $replay->{stats}->{questsProgress}->{$mission_id});
                push(@$mission_panel, $mission); 
            } else {
                push(@$mission_panel, { name => $mission_id, is_unknown => 1 });
            }
            $end->();
        });
    }
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

sub view {
    my $self  = shift;
    my $start = [ gettimeofday ];
    my $desc;

    $self->render_later;
    $self->stash('cachereplay' => 1);

    $self->load_replay(sub {
        my ($c, $e, $replay) = (@_);

        if(defined($replay)) {
            unless($self->is_allowed_to_view($replay)) {
                $self->respond(template => 'replay/view/denied', stash => { page => { title => $self->loc('page.replay.denied.title') }});
                return;
            }
            $self->actual_view_replay($replay, $start);
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

    my $title = sprintf('%s - %s - %s (%s)',
        $replay->{game}->{recorder}->{name},
        $self->get_recorder_vehicle($replay)->{vehicle}->{label},
        $self->map_name($replay),
        $self->app->wr_res->gametype->i18n($replay->{game}->{type})
        );

    my $description = sprintf('This is a replay of a %s match fought by %s, using the %s vehicle, on map %s', 
        $self->app->wr_res->gametype->i18n($replay->{game}->{type}), 
        $replay->{game}->{recorder}->{name}, 
        $self->get_recorder_vehicle($replay)->{vehicle}->{label},
        $self->map_name($replay),
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
        next if($achievements->is_battle($e->[0])); # don't want the battle awards to be in other awards
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
    my $pl_indexes = {};
    my $idx = 0;
    my $pl_members = {}; 

    foreach my $v (@{$replay->{roster}}) {
        next unless(defined($v->{platoon}));
        # platoon contains the prebattleID
        unless(defined($pl_indexes->{$v->{platoon}})) {
            $pl_indexes->{$v->{platoon}} = ++$idx;
        }
        $pl_members->{$v->{player}->{name}} = $pl_indexes->{$v->{platoon}};
    }

    $self->model('wot-replays.replays')->update({ _id => $replay->{_id} }, {
        '$inc' => { 'site.views' => 1 },
    } => sub {
        $replay->{site}->{views} += 1; 

        # generate the mission panel
        $self->generate_mission_panel($replay => sub {
            my $mission_panel = shift;
            $replay->{mission_panel} = $mission_panel;
            $self->respond(
                stash => {
                    pageid => 'browse', # really? yah really
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
        });
    });
}

1;
