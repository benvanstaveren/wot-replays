package WR::Elastic;
use Moose;
use ElasticSearch;
use ElasticSearch::SearchBuilder;

has '_elastic' => (is => 'ro', isa => 'ElasticSearch', lazy => 1, builder => '_build_elastic');

sub _build_elastic {
    my $self = shift;

    return ElasticSearch->new(
        servers     => '192.168.100.10', # es1.blockstackers.net
        transport   => 'http',
    );
}

sub setup {
    my $self = shift;

    $self->_elastic->create_index(
        index       => 'wotreplays',
        mappings    => {
            'replay'    =>  {
                _id => { 'index' => 'not_analyzed', 'store' => 'yes' },
            },
        },
    );
}

sub index {
    my $self    = shift;
    my $replay  = shift;

    # things that need to be altered are the _id which needs to be turned into a string
    $replay->{_id} = $replay->{_id}->to_string;

    # other things that need to be altered? None so far. 

    $self->_elastic->index(
        index   => 'wotreplays',
        type    => 'replay',
        id      => delete($replay->{_id}),
        data    => $replay,
    );
}

__PACKAGE__->meta->make_immutable;
