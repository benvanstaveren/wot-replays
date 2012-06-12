package WR::App::Controller::Replays::View;
use Mojo::Base 'WR::Controller';
use boolean;
use WR::Parser;
use WR::Query;
use FileHandle;
use Mojo::JSON;
use JSON::XS;

sub fuck_booleans {
    my $self = shift;
    my $obj = shift;
    my $forjsonxs = shift || 0;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_booleans($_, $forjsonxs) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_booleans($obj->{$field}, $forjsonxs);
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_booleans($_, $forjsonxs)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(ref($obj->{$field}) eq 'MongoDB::OID') {
                $obj->{$field} = $obj->{$field}->to_string();
            } elsif(ref($obj->{$field}) eq 'DateTime') {
                $obj->{$field} = $obj->{$field}->epoch;
            } elsif(ref($obj->{$field}) eq 'boolean') {
                if($forjsonxs) {
                    $obj->{$field} = ($obj->{$field}) ? JSON::XS::true() : JSON::XS::false();
                } else {
                    $obj->{$field} = ($obj->{$field}) ? Mojo::JSON::_Bool->new(1) : Mojo::JSON::_Bool->new(0);
                }
            }
        }
    }
    return $obj;
}

sub view {
    my $self = shift;
    my $desc;

    $self->db('wot-replays')->get_collection('replays')->update({ _id => $self->stash('req_replay')->{_id} }, { '$inc' => { 'site.views' => 1 } });

    if(defined($self->stash('format')) && $self->stash('format') eq 'json') {
        my $h = $self->fuck_booleans($self->stash('req_replay'), 1);
        delete($h->{file});
        delete($h->{id});
        $self->render(data => JSON::XS->new()->pretty(1)->encode($h));
    } else {
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
