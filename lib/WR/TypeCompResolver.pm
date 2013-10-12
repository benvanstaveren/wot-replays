package WR::TypeCompResolver;
use Mojo::Base '-base';
use Mango::BSON;
use Try::Tiny qw/try catch/;
use WR::Constants qw/nation_id_to_name decode_arena_type_id/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;

has 'coll'  => undef;
has 'cache' => sub { {} };

sub _fetch_one {
    my $self     = shift;
    my $typecomp = shift;
    my $cb       = shift;   

    if(defined($self->cache->{$typecomp})) {
        $cb->($self->cache->{$typecomp});
    } else {
        my $t = parse_int_compact_descr($typecomp);
        my $country = nation_id_to_name($t->{country});
        my $wot_id  = $t->{id};

        $self->coll->find_one({ country => $country, wot_id => $wot_id } => sub {
            my ($c, $e, $d) = (@_);

            if(defined($d) && !$e){
                $self->cache->{$typecomp} = $d;
                $cb->($d);
            } else {
                $cb->(undef);
            }
        });
    }
}

sub fetch {
    my $self   = shift;
    my $types  = shift; # arrayref, returns hashref of typecomp and value
    my $cb     = shift;

    $self->cache({}); # va-gina? :P

    $types = [ $types ] unless(ref($types) eq 'ARRAY');

    my $delay = Mojo::IOLoop->delay(sub {
        my ($delay, @results) = (@_);
        my $res = {};
        foreach my $r (@results) {
            $res->{$r->{t}} = $r->{v};
        }
        $cb->($res);
    });
    while(my $t = shift(@$types)) {
        my $end = $delay->begin(0);
        $self->_fetch_one($t => sub {
            my $r = (@_);
            $end->({ t => $t, v => $r });
        });
    }
    $delay->wait unless(Mojo::IOLoop->is_running);
}

1;
