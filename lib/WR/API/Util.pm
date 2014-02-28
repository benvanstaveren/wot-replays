package WR::API::Util;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON;

sub battleresult_submit {
    my $self = shift;
    my $data = $self->req->json || {};

    use Data::Dumper;

    $self->app->log->info(ref($self) . ' received body: ' . $self->req->body);
    $self->app->log->info(ref($self) . ' received json: ' . $self->req->json);

    $self->render_later;
    $self->model('wot-replays.battleresults_temp')->save({
        ctime   => Mango::BSON::bson_time, 
        data    => $data,
    } => sub {
        $self->render(text => 'OK', status => 200);
    });
}       

1;
