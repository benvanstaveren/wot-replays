package WR::App::Controller::Replays::View;
use Mojo::Base 'WR::App::Controller';

use boolean;
use WR::Query;
use Beanstalk::Client;
use Time::HiRes qw/gettimeofday tv_interval/;

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

sub view {
    my $self = shift;
    my $desc;
    my $format = $self->stash('format');

    $self->redirect_to(sprintf('%s.html', $self->req->url)) unless(defined($format));

    my $start = [ gettimeofday ];

    #$self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.views' => 1 } });

    my $replay = $self->stash('req_replay');
    my $r = { %$replay };
    if($replay->{complete}) {
        # loop across the enemy team (team 1)
        no warnings;
        foreach my $id (@{$replay->{teams}->[1]}) {
            $r->{sdk}->{s}->{$id} = (defined({ map { $_ => 1 } (@{$replay->{player}->{statistics}->{spotted}}) }->{$id})) ? 1 : 0;
            $r->{sdk}->{d}->{$id} = (defined({ map { $_ => 1 } (@{$replay->{player}->{statistics}->{damaged}}) }->{$id})) ? 1 : 0;
            $r->{sdk}->{k}->{$id} = (defined({ map { $_ => 1 } (@{$replay->{player}->{statistics}->{killed}}) }->{$id})) ? 1 : 0;
        }

        # get our own team
        foreach my $id (@{$replay->{teams}->[0]}) {
            $r->{tk}->{td}->{$id} = (defined($replay->{player}->{statistics}->{teamkill}->{hash}->{$id})) ? 1 : 0;
            my $e = $replay->{player}->{statistics}->{teamkill}->{hash}->{$id};
            $r->{tk}->{k}->{$id} = (defined($e) && $e->{isKill} > 0) ? 1 : 0;

            $r->{tk}->{means}->{$id} = (defined($e)) 
                ? ($e->{means} == 3)
                    ? 'shooting'
                    : ($e->{means} == 1)
                        ? 'ramming'
                        : ($e->{means} == 4)
                            ? 'shooting, ramming'
                            : 'unknown'
                :   'unknown';
            
        }
        use warnings;
    }

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
            $r->{player}->{statistics}->{earned}->{xp},
            ($r->{player}->{statistics}->{earned}->{factor} > 1) 
                ? sprintf(' (x%d)', $r->{player}->{statistics}->{earned}->{factor})
                : '',
            $r->{player}->{statistics}->{earned}->{credits});
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
            my $frags = $r->{vehicles_hash}->{$player}->{frags} || 0;
            $list->{$player} = $frags;
        }

        foreach my $id (sort { $list->{$b} <=> $list->{$a} } (keys(%$list))) {
            push(@{$frag_sorted_teams->[$tid]}, $id);
        }
    }

    $r->{teams} = $frag_sorted_teams;

    if(my $yt = $r->{site}->{youtube}) {
        if($yt =~ /^http/) {
            my $u = Mojo::URL->new($r->{site}->{youtube});
            if($u->host eq 'youtu.be') {
                $r->{site}->{youtube} = $u->path;
            } elsif($u->host eq 'www.youtube.com' ) {
                $r->{site}->{youtube} = $u->query->param('v');
            }
        } else {
            warn 'already id', "\n";
        }
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

sub chat {
    my $self = shift;
    my $r = $self->stash('req_replay');
    my $waitreasons = $self->stash('config')->{waitreasons};

    if($r->{chatProcessed}) {
        # chat message formatting:
        #
        # -> local team: nick green, text darker green
        # -> enemy team: nick red, text white
        my $messages = [];
        my $my_team  = $r->{vehicles_hash_name}->{$r->{player}->{name}}->{team};

        foreach my $message ($self->db('wot-replays')->get_collection('replays.chat')->find({
            replay_id => $r->{_id},
            channel   => { '$nin' => [ 'unknown', 'noid:ch0', 'noid:ch1', 'noid:req' ] }
        })->sort({ sequence => 1 })->all()) {
            my $st = $r->{vehicles_hash_name}->{$message->{source}}->{team};
            push(@$messages, {
                source => $message->{source},
                body   => $message->{body},
                target => ($message->{channel} eq '#chat:channels/battle/team') ? 'team' : 'all',
                sourcetype => ($st == $my_team) ? 'team' : 'enemy',
            });
        }
        $self->respond(
            stash => {
                messages => $messages,
            },
            template => 'replay/view/chat',
        );
    } else {
        # drop the job into mongodb 
        my $make = 0;
        if(my $job = $self->db('wot-replays')->get_collection('jobs')->find_one({ type => 'chat', replay => $r->{_id} })) {
            $make = 1 if($job->{created} + 3600 < time());
        } else {
            $make = 1;
        }

        if($make) {
            my $job = {
                type    =>  'chat',
                replay  =>  $r->{_id},
                created =>  time(),
            };
            my $id = $self->db('wot-replays')->get_collection('jobs')->insert($job);
            my $bs = Beanstalk::Client->new({ server => 'localhost', default_tube => 'wot-replays' });
            $bs->put({ ttr => 300, data => $id->to_string });
        }

        $self->respond(
            stash => {
                waitreason => $waitreasons->[int(rand(scalar(@$waitreasons)))],
                rid => $r->{_id},
            }, template => 'replay/view/chat_wait');
    }
}

1;
