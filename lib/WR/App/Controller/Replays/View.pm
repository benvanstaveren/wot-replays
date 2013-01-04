package WR::App::Controller::Replays::View;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Query;
use Time::HiRes qw/gettimeofday tv_interval/;
use JSON::XS;

sub stats {
    my $self = shift;

    $self->render(json => {
        views => $self->stash('req_replay')->{site}->{views} + 0,
        downloads => $self->stash('req_replay')->{site}->{downloads} + 0,
        likes => $self->stash('req_replay')->{site}->{like} + 0,
    });
}

sub incview {
    my $self = shift;
    $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.views' => 1 } });
    $self->render(json => { ok => 1 });
}

sub fuck_jsonxs {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_jsonxs($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_jsonxs($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_jsonxs($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(boolean::isBoolean($obj->{$field})) {
                $obj->{$field} = ($obj->{$field}) ? JSON::XS->true : JSON::XS->false;
            }
        }
        return $obj;
    }
}


sub view {
    my $self = shift;
    my $desc;
    my $format = $self->stash('format');

    $self->redirect_to(sprintf('%s.html', $self->req->url)) unless(defined($format));

    if($format eq 'json') {
        my $j = JSON::XS->new()->pretty->allow_blessed(1)->convert_blessed(1);
        $self->render(text => $j->encode($self->fuck_jsonxs($self->stash('req_replay'))));
        return;
    }

    $self->stash('cachereplay' => 1);

    my $start = [ gettimeofday ];

    my $replay = $self->stash('req_replay');
    my $r = { %$replay };

    my $title = sprintf('%s - %s - %s (%s), %s',
        $r->{player}->{name},
        $self->stash('wr')->{vehicle_name}->($r->{player}->{vehicle}->{full}),
        $self->stash('wr')->{map_name}->($r->{map}->{id}),
        $self->app->wr_res->{'gametype'}->i18n($r->{game}->{type}),
        ($r->{game}->{isWin} > 0) 
            ? 'Victory'
            : ($r->{game}->{isDraw} > 0)
                ? 'Draw'
                : 'Defeat');
    if($r->{complete}) {
        $title .= sprintf(', earned %d xp%s, %d credits',
            $r->{statistics}->{xp},
            ($r->{statistics}->{dailyXPFactor10} > 10) 
                ? sprintf(' (x%d)', $r->{statistics}->{dailyXPFactor10}/10)
                : '',
            $r->{statistics}->{credits});
    }

    my $description = sprintf('This is a replay of a %s match fought by %s, using the %s vehicle, on map %s', 
        $self->app->wr_res->{'gametype'}->i18n($r->{game}->{type}), 
        $r->{player}->{name}, 
        $self->stash('wr')->{vehicle_name}->($r->{player}->{vehicle}->{full}),
        $self->stash('wr')->{map_name}->($r->{map}->{id})
    );

    # need to bugger up the teams and sort them by the number of frags which we can obtain from the vehicle hash
    my $frag_sorted_teams = [];

    foreach my $tid (0..1) {
        my $list = {};
        foreach my $player (@{$r->{teams}->[$tid]}) {
            my $frags = $r->{vehicles}->{$player}->{frags} || 0;
            $list->{$player} = $frags;
        }

        foreach my $id (sort { $list->{$b} <=> $list->{$a} } (keys(%$list))) {
            push(@{$frag_sorted_teams->[$tid]}, $id);
        }
    }

    my $playerteam = $r->{player}->{team} - 1;

    if($playerteam == 0) {
        $r->{teams} = [ $frag_sorted_teams->[0], $frag_sorted_teams->[1] ];
    } else {
        $r->{teams} = [ $frag_sorted_teams->[1], $frag_sorted_teams->[0] ];
    }

    $self->stash('timing_view' => tv_interval($start, [ gettimeofday ]));

    $self->respond(
        stash => {
            replay => $r,
            page   => {
                title => $title,
                description => $description,
            },
            related => $self->related,
        }, 
        template => 'replay/view/index',
    );
}

sub related {
    my $self = shift;
    my $r = $self->stash('req_replay');

    return [] unless($r->{complete});

    return [ map { WR::Query->fuck_tt($_) } $self->db('wot-replays')->get_collection('replays')->find({
        'site.visible' => true,
        'game.arena_id' => $r->{game}->{arena_id},
        '_id' => { '$nin' => [ $r->{_id} ] }
        })->all() ];
}

1;
