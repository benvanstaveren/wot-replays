package WR::App::Controller::Replays::Export;
use Mojo::Base 'WR::App::Controller';
use boolean;
use Mojo::JSON;

sub download {
    my $self = shift;
    my $id   = $self->stash('replay_id');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => bless({ value => $id }, 'MongoDB::OID') })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $replay->{_id} }, { '$inc' => { 'site.downloads' => 1 } });
        my $url = Mojo::URL->new(sprintf('http://dl.wot-replays.org/%s', $replay->{file}));
        $self->redirect_to($url->to_string);
    } else {
        $self->render(status => 404, text => 'Not Found');
    }
}

1;
