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

    if(defined($q) && defined($s)) {
        my $url = sprintf('http://statterbox.com/api/v1/%s/search/clan?s=%s&q=%s', 
            $self->stash('config')->{secrets}->{statterbox},
            $s,
            $q
        );

        $self->ua->get($url => sub {
            my ($ua, $tx) = (@_);
            if(my $res = $tx->success) {
                $self->stash(search_results => $res->json('/result')) if($res->json('/ok') == 1);
            }
            $self->stash('query' => $q, server => $s);
            $self->respond(template => 'clan/index');
        });
    } else {
        $self->respond(template => 'clan/index');
    }
}

1;
