package WR::App::Controller::Clan;
use Mojo::Base 'WR::App::Controller';
use WR::Query;
use Mango::BSON;

sub involved { return shift->view(1) }
sub clan_bridge { return 1; }
sub index {
    my $self = shift;
    my $q    = $self->req->param('q');
    my $s    = $self->req->param('s'); 

    $self->render_later;

    $s = 'asia' if($s eq 'sea');

    if(defined($q) && defined($s)) {
        my $url = 'http://api.statterbox.com/wot/clan/list';
        my $form = {
            application_id => $self->get_config('statterbox.server'),
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
            $self->stash(query => $q, server => $s);
            $self->respond(template => 'clan/index');
        });
    } else {
        $self->respond(template => 'clan/index');
    }
}

1;
