package WR::API::Util;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON;
use WR::Util::Pickle;
use Mojo::Util qw/b64_decode/;
use Try::Tiny;

sub battleresult_submit {
    my $self = shift;
    my $data = $self->req->json;

    $self->render_later;
    if(defined($data->{arena_id}) && defined($data->{battleResult})) {
        my $br_64 = b64_decode($data->{battleResult});
        my $p = WR::Util::Pickle->new(data => $br_64);
        my $br = undef;

        try {
            $br = $p->unpickle;
        } catch {
            $br = undef;
        };

        if(defined($br)) {
            $self->model('wot-replays.battleresults')->save({
                ctime           =>  Mango::BSON::bson_time,
		arena_id	=> $data->{arena_id} . '',
                battle_result   =>  $br,
            } => sub {
                $self->render(text => 'DATA:OK BR:OK SAVE:OK', status => 200);
            });
        } else {
            $self->render(text => 'DATA:OK BR:FAIL', status => 200);
        }
    } else {
        $self->render(text => 'DATA:FAIL', status => 200);
    }
}       

1;
