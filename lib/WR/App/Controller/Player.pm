package WR::App::Controller::Player;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use Mango::BSON;

=pod
sub get_quick_stats {
    my $self = shift;
    my $server = shift;
    my $player = shift;

    my $cmd = Tie::IxHash->new(
        group => {
            ns => 'replays',
            initial => { 
                kills => 0, 
                damages => 0, 
                spots => 0, 
                c => 0, 
                damagedone => 0,
                vehicles => {},
                maps => {},
                },
            key => { 'player.name' => 1 },
            cond => {
                'player.name'   => $player,
                'player.server' => $server,
                'site.visible'  => true,
                'complete'      => true,
            },
            '$reduce' => q|function(obj, prev) { prev.kills += obj.statistics.kills; prev.damages += obj.statistics.damaged; prev.spots += obj.statistics.spotted; prev.c += 1; prev.damagedone += obj.statistics.damageDealt; if(!prev.vehicles[obj.player.vehicle.full]) { prev.vehicles[obj.player.vehicle.full] = 1 } else { prev.vehicles[obj.player.vehicle.full] += 1; } if(!prev.maps[obj.map.id]) { prev.maps[obj.map.id] = 1 } else {  prev.maps[obj.map.id] += 1 } }|,
            finalize => q|function(out) { out.damagedone_a = (out.damagedone > 0 && out.c > 0) ? out.damagedone/out.c : 0; out.kills_a = (out.kills > 0 && out.c > 0) ?out.kills / out.c : 0; out.damages_a = (out.damages > 0 && out.c > 0) ? out.damages / out.c : 0; out.spots_a = (out.spots > 0 && out.c > 0) ? out.spots / out.c : 0; return out; }|
        }
    );

    my $res = $self->db('wot-replays')->run_command($cmd);
    return $res->{retval}->[0] || {};
}

sub ambi {
    my $self = shift;
    my $player = $self->stash('player_name');

    # this might take a while...
    my $mapf = 'function() { emit(this.player.server, 1); }';
    my $redf = 'function(keys, values) { var sum = 0; values.forEach(function(v) { sum += v }); return sum; }';

    my $cmd = Tie::IxHash->new(
        "mapreduce" => "replays",
        map => $mapf,
        reduce => $redf,
        query => { 'player.name' => $player },
        out => { inline => 1 }
    );
    my $res = $self->db('wot-replays')->run_command($cmd);
    my $servers = [];
    if($res->{ok} == 1) {
        foreach my $r (@{$res->{results}}) {
            push(@$servers, $r->{_id});
        }
    } else {
        $servers = [];
    }
    if(scalar(@$servers) == 1) {
        $self->redirect_to(sprintf('/player/%s/%s', $servers->[0], $player));
    } else {
        $self->respond(stash => {
            page => { title => 'Finding Player' },
            servers => $servers,
            template => 'player/ambi',
        });
    }
}
=cut

sub involved {
    return shift->view(1);
}

sub player_bridge { return 1; }

sub index {
    my $self = shift;

    $self->respond(template => 'player/index');
}

sub latest {
    my $self = shift;
    my $query = {
        'game.recorder.name'   => $self->stash('player_name'),
        'game.server' => $self->stash('server'),
        'site.visible'  => Mango::BSON::bson_true,
    };

    $self->render_later;
    $self->model('wot-replays.replays')->find($query)->sort({ 'site.uploaded_at' => -1 })->limit(1)->all(sub {
        my ($c, $e, $d) = (@_);
        
        if($d && $d->[0]) {
            my $replay = $d->[0];
            if(defined($self->stash('format')) && $self->stash('format') =~ /png|jpg/) {
                # hashify the string
                $self->redirect_to(sprintf('http://dl.wt-replays.org/%s.jpg', $self->hashbucket($replay->{_id} . '')));
            } else {
                $self->redirect_to(sprintf('/replay/%s.html', $replay->{_id}->to_string));
            }
        } else {
            $self->redirect_to(sprintf('/player/%s/%s', $self->stash('server'), $self->stash('player_name')));
        }
    });
}

sub view { 
    my $self = shift;
    my $inv  = shift;
    my $server = $self->stash('server');
    my $player = $self->stash('player_name');

    $self->render_later;

    $self->model('wot-replays.replays')->find({ 'game.server' => $server, 'site.visible' => Mango::BSON::bson_true, 'game.recorder.name' => $player })->count(sub {
        my ($c, $e, $total) = (@_);

        $self->model('wot-replays.replays')->find({ 
            'game.server' => $server, 
            'site.visible' => Mango::BSON::bson_true, 
            'involved.players' => { '$in' => [ $player ] }, 
            'game.recorder.name' => { '$ne' => $player }
        })->count(sub {
            my ($c, $e, $involved) = (@_);

            $self->respond(
                template => ($inv) ? 'player/involved' : 'player/view',
                stash    => {
                    total_replays => $total,
                    total_involved => $involved,
                    #statistics => $self->get_quick_stats($server => $player),
                    page => {
                        title => sprintf('Players &raquo; %s', $player),
                    },
                }
            );
        });
    });
}

1;
