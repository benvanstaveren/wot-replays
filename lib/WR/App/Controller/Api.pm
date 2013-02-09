package WR::App::Controller::Api;
use Mojo::Base 'WR::App::Controller';

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
