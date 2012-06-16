package WR::App::Controller::Replays::View;
use Mojo::Base 'WR::App::Controller';

use boolean;
use WR::Query;

sub view {
    my $self = shift;
    my $desc;

    $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.views' => 1 } });

    my $replay = $self->stash('req_replay');
    my $r = { %$replay };
    if($replay->{complete}) {
        $r->{f} = {
            spotted => sub {
                my $id = shift;
                no warnings;
                return (
                    { map { $_ => 1 } (@{$replay->{player}->{statistics}->{spotted}}) }->{$id} > 0
                ) ? 1 : 0;
            },
            killed => sub {
                my $id = shift;
                no warnings;
                return (
                    { map { $_ => 1 } (@{$replay->{player}->{statistics}->{killed}}) }->{$id} > 0
                ) ? 1 : 0;
            },
            damaged => sub {
                my $id = shift;
                no warnings;
                return (
                    { map { $_ => 1 } (@{$replay->{player}->{statistics}->{damaged}}) }->{$id} > 0
                ) ? 1 : 0;
            },
            team_killed => sub {
                my $id = shift;
                my $e  = $replay->{player}->{statistics}->{teamkill}->{hash}->{$id};
                return 1 if(defined($e) && $e->{isKill} > 0);
                return 0;
            },
            team_damaged => sub {
                my $id = shift;
                no warnings;
                return (defined($replay->{player}->{statistics}->{teamkill}->{hash}->{$id})) ? 1 : 0;
            },
            team_damage_type => sub {
                my $id = shift;
                my $e  = $replay->{player}->{statistics}->{teamkill}->{hash}->{$id};
                my @r  = '';

                return 'unknown' unless($e);
                return ($e->{means} == 3)
                    ? 'shooting'
                    : ($e->{means} == 1)
                        ? 'ramming'
                        : ($e->{means} == 4)
                            ? 'shooting, ramming'
                            : 'unknown';
            },
        },
    }
    # FIXME FIXME need to move WR::Auto data into Res core
    my $title = sprintf('This is a replay of a match fought by %s, using the %s vehicle, on map %s', $r->{player}->{name}, $r->{player}->{vehicle}->{name}, $r->{map}->{id});
    $self->respond(
        stash => {
            replay => $r,
            page   => {
                title => 'View Replay',
                description => $title,
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
