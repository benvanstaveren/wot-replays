package WR::Controller::Replays::Export;
use Mojo::Base 'WR::Controller';
use boolean;
use WR::Parser;
use Mojo::JSON;

sub raw {
    my $self = shift;
    my $id   = $self->stash('replay_id');
    my $gfs  = $self->db('wot-replays')->get_gridfs();

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id })) {
        if(my $file = $gfs->find_one({ replay_id => $id })) {
            my $parser = WR::Parser->new();
            $parser->parse($file->slurp);
            $self->render(content_type => 'text/plain', data => Mojo::JSON->new()->encode($parser->chunks));
        } else {
            $self->render(status => 404, text => 'Not Found');
        }
    } else {
        $self->render(status => 404, text => 'Not Found');
    }
}

sub download {
    my $self = shift;
    my $id   = $self->stash('replay_id');
    my $gfs  = $self->db('wot-replays')->get_gridfs();

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => $id })) {
        if(my $file = $gfs->find_one({ replay_id => $id })) {
            $self->db('wot-replays')->get_collection('replays')->update({ _id => $id }, { '$inc' => { 'site.downloads' => 1 } });
            $self->render(data => $file->slurp);
        } else {
            $self->render(status => 404, text => 'Not Found');
        }
    } else {
        $self->render(status => 404, text => 'Not Found');
    }
}

1;
