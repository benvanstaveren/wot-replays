package WR::Elastic;
use Moose;
use ElasticSearch;
use ElasticSearch::SearchBuilder;

has '_elastic' => (is => 'ro', isa => 'ElasticSearch', lazy => 1, builder => '_build_elastic');

sub _build_elastic {
    my $self = shift;

    return ElasticSearch->new(
        servers     => '192.168.100.10:9200', # es1.blockstackers.net
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

sub fuck_jsonxs {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_jsonxs($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_jsonxs($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_jsonxs($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(boolean::isBoolean($obj->{$field})) {
                $obj->{$field} = ($obj->{$field}) ? JSON::XS->true : JSON::XS->false;
            }
        }
        return $obj;
    }
}

sub index {
    my $self    = shift;
    my $replay  = shift;

    # things that need to be altered are the _id which needs to be turned into a string
    $replay->{_id} = $replay->{_id}->to_string;

    # need to fix equipment to not have empties if they're there 
    foreach my $v (values(%{$replay->{vehicle_fittings}})) {
        delete($v->{rawdata});
        my $e = $v->{data}->{equipment};
        my $n = [];
        foreach my $item (@$e) {
            push(@$n, $item) if(defined($item));
        }
        $v->{data}->{equipment} = $n;
    }

    $self->_elastic->index(
        index   => 'wotreplays',
        type    => 'replay',
        id      => delete($replay->{_id}),
        data    => $self->fuck_jsonxs($replay),
    );
}

__PACKAGE__->meta->make_immutable;
