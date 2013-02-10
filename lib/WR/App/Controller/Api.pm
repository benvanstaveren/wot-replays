package WR::App::Controller::Api;
use Mojo::Base 'WR::App::Controller';
use WR::ServerFinder;
use WR::PlayerProfileData;

sub bridge {
    my $self = shift;

    if(my $origin = $self->req->headers->header('Origin')) {
        if($origin =~ /\.wot-replays\.org$/) {
            $self->res->headers->header('Access-Control-Allow-Origin' => $origin);
        } else {
            $self->render(text => 'Forbidden', status => 403);
        }
    } else {
        $self->render(text => 'Forbidden', status => 403);
    }
    return 1;
}

sub player {
    my $self = shift;
    my $pn   = $self->req->param('player');
    my $ps   = $self->req->param('server');

    # need to get the playerid based on the above, which means that
    # if they aren't in the server finder cache, they have no replays
    # stored
    if(my $s = $self->model('wot-replays.cache.server_finder')->find_one({
        server => $ps,
        user_name => $pn,
    })) {
        my $ppd = WR::PlayerProfileData->new(
            db      => $self->db,
            id      => $s->{user_id} + 0,
            name    => $pn,
            server  => $ps,
        );

        if(my $user = $ppd->load_user) {
            $self->render(json => { ok => 1, player => $user });
        } else {
            $self->render(json => { ok => 0 });
        }
    } else {
        $self->render(json => { ok => 0 });
    }
}

sub bootstrap {
    my $self = shift;
    my $data = {};

    my $cursor = $self->db('wot-replays')->get_collection('data.vehicles')->find();
    while(my $v = $cursor->next()) {
        my $country = delete($v->{country});
        my $id      = delete($v->{_id});
        $data->{vehicles}->{$country}->{$id} = $v;
    }

    $cursor = $self->db('wot-replays')->get_collection('data.maps')->find();
    while(my $v = $cursor->next()) {
        $data->{maps}->{ delete($v->{_id}) } = $v->{label};
    }

    $cursor = $self->db('wot-replays')->get_collection('data.components')->find();
    while(my $v = $cursor->next()) {
        my $country = delete($v->{country});
        my $component = delete($v->{component});
        my $id = delete($v->{component_id});
        delete($v->{_id});
        $data->{components}->{$country}->{$component}->{$id} = $v;
    }

    $self->render(json => $data);
}

1;
