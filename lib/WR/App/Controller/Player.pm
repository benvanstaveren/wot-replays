package WR::App::Controller::Player;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use boolean;
use WR::MR;

sub index {
    my $self = shift;

    $self->respond(
        template => 'player/index',
        stash => {
            page => { title => 'Players' },
        },
    );
}

sub ambi {
    my $self = shift;
    my $player = $self->stash('player_name');

    # this might take a while...
    my $mapf = 'function() { emit(this.player.server, 1); }';
    my $redf = 'function(keys, values) { var sum = 0; values.forEach(function(v) { sum += v }); return sum; }';

    # do a manual map/reduce using WR::MR
    my $mr = WR::MR->new();

    my $res = $mr->map_reduce('replays', 
        map => $mapf,
        reduce => $redf,
        query => { 'player.name' => $player },
        out => { inline => 1 }
    );

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

sub involved {
    return shift->view(1);
}

sub view { 
    my $self = shift;
    my $inv  = shift;
    my $server = $self->stash('server');
    my $player = $self->stash('player_name');

    my $t_stats = $self->db('wot-replays')->get_collection('replays')->group({
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
            'player.name' => $player,
            'player.server' => $server,
            'site.visible' => true,
            'complete' => true,
        },
        reduce => q|function(obj, prev) { prev.kills += obj.player.statistics.killed.length; prev.damages += obj.player.statistics.damaged.length; prev.spots += obj.player.statistics.spotted.length; prev.c += 1; prev.damagedone += obj.player.statistics.damage.done; if(!prev.vehicles[obj.player.vehicle.full]) { prev.vehicles[obj.player.vehicle.full] = 1 } else { prev.vehicles[obj.player.vehicle.full] += 1; } if(!prev.maps[obj.map.id]) { prev.maps[obj.map.id] = 1 } else {  prev.maps[obj.map.id] += 1 } }|,
        finalize => q|function(out) { out.damagedone_a = (out.damagedone > 0 && out.c > 0) ? out.damagedone/out.c : 0; out.kills_a = (out.kills > 0 && out.c > 0) ?out.kills / out.c : 0; out.damages_a = (out.damages > 0 && out.c > 0) ? out.damages / out.c : 0; out.spots_a = (out.spots > 0 && out.c > 0) ? out.spots / out.c : 0; return out; }|
    })->{retval}->[0];

    $self->respond(
        template => ($inv) ? 'player/involved' : 'player/view',
        stash    => {
            total_replays => $self->db('wot-replays')->get_collection('replays')->find({ 
                'player.name' => $player, 
                'player.server' => $server, 
                'site.visible' => true 
                })->count(),
            total_involved => $self->db('wot-replays')->get_collection('replays')->find({ 
                'player.server' => $server, 
                'vehicles.name' => $player,
                'player.name' => { '$ne' => $player },
                'site.visible' => true 
                })->count(),
            statistics => $t_stats,
            page => {
                title => sprintf('Players &raquo; %s', $player),
            },
        }
    );
}

1;
