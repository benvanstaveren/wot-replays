package WR::App::Controller::Replays::Export;
use Mojo::Base 'WR::App::Controller';
use boolean;
use Mojo::JSON;

sub download {
    my $self = shift;
    my $id   = $self->stash('replay_id');
    my $gfs  = $self->db('wot-replays')->get_gridfs();

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id })) {
        if(my $file = $gfs->find_one({ replay_id => $id })) {
            $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$inc' => { 'site.downloads' => 1 } });

            $self->redirect_to(sprintf('http://dl.wot-replays.org/%s', $file->info->{filename}));
        } else {
            $self->render(status => 404, text => 'Not Found');
        }
    } else {
        $self->render(status => 404, text => 'Not Found');
    }
}

1;
