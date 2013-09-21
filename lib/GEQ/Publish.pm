package GEQ::Publish;
use Mojo::Base '-base';
use Mango::BSON;
use Data::Dumper;

has 'db'    => undef;
has 'cname' => 'ghetto_event_queue';
has 'index' => 0;
has 'blocking' => 0;

sub publish {
    my $self = shift;
    my $evt  = shift;
    my $data = shift;
    my $cb   = shift;

    warn '[GEQ:Publish]: db: ', $self->db, "\n";

    unless($self->index) {
        warn 'indexing', "\n";
        $self->db->collection($self->cname)->ensure_index({ time => 1 }, { expireAfterSeconds => 120 });
        $self->index(1);
    }

    # if data has a 'scope' variable, that indicates that it's scoped to a specific key
    my $scope = delete($data->{scope}) || '*';
    my $event = {
        event => { name => $evt, data => $data },
        time  => Mango::BSON::bson_time,
        scope => $scope,
    };
    warn 'pre-insert', "\n";

    if($self->blocking) {
        if($self->db->collection($self->cname)->insert($event)) {
            warn '[GEQ:Publish]: published: ', Dumper($event), "\n";
            $cb->(0);
        } else {
            warn '[GEQ:Publish]: publish failed for: ', Dumper($event), "\n";
            $cb->(1);
        }
    } else {
        $self->db->collection($self->cname)->insert($event => sub {
            my ($c, $e, $d) = (@_);
            warn 'pub?', "\n";
            if($e) {
                warn '[GEQ:Publish]: nb publish failed for: ', Dumper($event), "\n", 'error: ', $e, "\n";
                $cb->(0, $e) if($cb);
            } else {
                warn '[GEQ:Publish]: nb published: ', Dumper($event), "\n";
                $cb->(1) if($cb);
            }
        });
    }
    warn 'post-insert', "\n";
}

1;
