package WR::App::Controller::Player;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use Mango::BSON;

sub involved { return shift->view(1) }
sub player_bridge { return 1; }

sub index {
    my $self = shift;
    my $q    = $self->req->param('q');
    my $s    = $self->req->param('s'); 

    $self->render_later;
    $s = 'asia' if($s eq 'sea');

    if(defined($q) && defined($s)) {
        my $url = 'http://api.statterbox.com/wot/account/list';
        my $form = {
            application_id => $self->config->{statterbox}->{server},
            cluster        => $s,
            search         => $q,
        };
        $self->ua->post($url => form => $form => sub {
            my ($ua, $tx) = (@_);
            if(my $res = $tx->success) {
                $self->stash(search_results => $res->json('/data')) if($res->json('/status') eq 'ok');
                $self->stash(error => $res->json('/error')) if($res->json('/status') ne 'ok');
            } else {
                $self->stash(search_results => []);
            }
            $self->stash('query' => $q, server => $s);
            $self->respond(template => 'player/index');
        });
    } else {
        $self->respond(template => 'player/index');
    }
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
                $self->redirect_to(sprintf('%s/%s', $self->stash('config')->{urls}->{banners}, $replay->{site}->{banner}->{url_path}));
            } else {
                $self->redirect_to(sprintf('/replay/%s.html', $replay->{_id}->to_string));
            }
        } else {
            $self->redirect_to(sprintf('/player/%s/%s', $self->stash('server'), $self->stash('player_name')));
        }
    });
}

1;
