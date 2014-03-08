package WR::Provider::WN8;
use Mojo::Base 'WR::Provider::WNx';

has 'expected'  => sub { {} };
has '__log'     => undef;
has 'ua'        => undef;
has 'cluster'   => undef;
has 'key'       => undef;

sub _log {
    my $self = shift;
    my $l    = shift;
    
    $self->__log->$l(join('', '[WR::Provider::WN8]: ', @_));
}

sub debug { shift->_log('debug', @_) }
sub info { shift->_log('info', @_) }
sub error { shift->_log('error', @_) }

sub all {
    my $self = shift;
    my $list = shift;
    my $cb   = shift;   # called as (self, <hash of id => wn8 values>)

    $self->ua->post('http://api.statterbox.com/wot/account/summary' => form => {
        cluster         => $self->cluster,
        application_id  => $self->key,
        account_id      => join(',', @$list),
    } => sub {
        my ($ua, $tx) = (@_);
        my $h = {};

        if(my $res = $tx->success) {
            if($res->json('/status') eq 'ok') {
                my $data = $res->json('/data');
                foreach my $id (@$list) {
                    if(defined($data->{$id}) && ref($data->{$id}) eq 'HASH') {
                        $h->{$id} = $data->{$id}->{rating}->{wn8};
                    

                return $cb->($self, { map { $_ => $data->{$_}->{rating}->{wn8}
            } else {
                return $cb->($self, undef);
            }
        } else {
            return $cb->($self, undef);
        }
    });
}


sub _calculate {
    my $self = shift;
    my $data = shift;
    my $res  = undef;
    
    my $exp     = {};
    my $totalb  = 0;

    foreach my $vid (keys(%{$data->{vehicles}})) {
        $self->debug('hey, expected value for vid ', $vid, ' is not there..') unless(defined($self->expected->{$vid + 0}));
        # this sets up the expected values overall on the account for this stuff
        for(qw/damage frags spot def/) {
            $exp->{$_} += $self->expected->{$vid + 0}->{$_} * $data->{vehicles}->{$vid}->{battles};
        }
    
        # expected winrate is a bit of a miffy iffy thing
        $exp->{wr} += $self->expected->{$vid + 0}->{wr};
    }
    $exp->{wr} = sprintf('%.2f', $exp->{wr} / scalar(keys(%{$data->{vehicles}})));

    my $actual = {
        wr      => ($data->{victories}->{percentage} == -1) ? $exp->{wr} : $data->{victories}->{percentage},
        damage  => $data->{damage_dealt}->{value},
        frags   => $data->{destroyed}->{value},
        spot    => $data->{spotted}->{value},
        def     => $data->{defense}->{value},
    };

    my $rDAMAGE     = sprintf('%.2f', $actual->{damage} / $exp->{damage});
    my $rSPOT       = sprintf('%.2f', $actual->{spot} / $exp->{spot});
    my $rFRAG       = sprintf('%.2f', $actual->{frags} / $exp->{frags});
    my $rDEF        = sprintf('%.2f', $actual->{def} / $exp->{def});
    my $rWIN        = sprintf('%.2f', $actual->{wr} / $exp->{wr});

    my $rWINc       = $self->max(0, ($rWIN - 0.71) / (1 - 0.71));
    my $rDAMAGEc    = $self->max(0, ($rDAMAGE - 0.22) / (1 - 0.22));
    my $rFRAGc      = $self->max(
        0, 
        $self->min($rDAMAGEc + 0.2, ($rFRAG - 0.12) / (1 - 0.12))
    );
    my $rSPOTc      = $self->max(
        0, 
        $self->min($rDAMAGEc + 0.1, ($rSPOT - 0.38) / (1 - 0.38))
    );
    my $rDEFc       = $self->max(
        0, 
        $self->min($rDAMAGEc + 0.1, ($rDEF - 0.10) / (1 - 0.10))
    );

    $res = 
        980 * $rDAMAGEc +
        210 * $rDAMAGEc * $rFRAGc +
        155 * $rFRAGc   * $rSPOTc +
        75  * $rDEFc    * $rFRAGc +
        145 * $self->min(1.8, $rWINc)
        ;

    return sprintf('%.0f', $res) + 0;
}

1;
