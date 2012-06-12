package WR::App::Controller::Map;
use Mojo::Base 'WR::Controller';
use boolean;

sub index {
    my $self = shift;

    # get the number of matches per map and order them like that
    my $res = $self->db('wot-replays')->get_collection('replays')->group({
        initial => { count => 0 },
        key => { 'map.id' => 1 },
        cond => { 
            'site.visible' => true
        },
        reduce => q|function(obj, prev) { prev.count += 1 }|,
    })->{retval};

    my $map_hash = { map { $_->{'map.id'} => $_->{count} } @$res };
    my $map_list = [];

    my $cursor = $self->db('wot-replays')->get_collection('data.maps')->find();

    while(my $o = $cursor->next()) {
        push(@$map_list, { 
            id => $o->{_id},
            count => $map_hash->{$o->{_id}} || 0,
        });
    }

    # re-order the map list
    $map_list = [ sort { $b->{count} <=> $a->{count} } (@$map_list) ];

    $self->respond(
        template => 'map/index',
        stash => {
            map_list => $map_list,
            page => { title => 'Maps' },
        },
    );
}

sub view {
    my $self = shift;
    my $map_id = shift;

    my $t_stats = $self->db('wot-replays')->get_collection('replays')->group({
        initial => { 
            c => 0, 
            win => 0,
            loss => 0,
            draw => 0
            },
        key => { 'player.name' => 1 },
        cond => {
            'map.id' => $map_id,
            'site.visible' => true,
            'complete' => true,
        },
        reduce => q|
function(obj, prev) { 
    if(obj.game.isDraw == true) { 
        prev.draw += 1; 
    } else { 
        if(obj.game.isWin == true) { 
            prev.win += 1; 
        } else { 
            prev.loss += 1; 
        } 
    } 
    prev.c += 1;
}|,
    })->{retval}->[0];

    my $m_obj = $self->db('wot-replays')->get_collection('data.maps')->findOne({ _id => $map_id });

    $self->respond(
        template => 'map/view',
        stash    => {
            statistics => $t_stats,
            page => {
                title => sprintf('Maps &raquo; %s', $m_obj->{label}),
            },
        }
    );
}

1;
