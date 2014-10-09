package WR::Provider::WN8;
use Mojo::Base 'WR::Provider::WNx';

has 'expected'  => sub { {} };
has '__log'     => undef;
has 'ua'        => undef;
has 'cluster'   => undef;
has 'key'       => undef;

use constant RATING_MAP => [
    [ 1,        300,    'beginner'      ],
    [ 300,      449,    'basic'         ],
    [ 450,      649,    'belowaverage'  ],
    [ 650,      899,    'average'       ],
    [ 900,      1199,   'aboveaverage'  ],
    [ 1200,     1599,   'good'          ],
    [ 1600,     1999,   'verygood'      ],
    [ 2000,     2449,   'great'         ],
    [ 2450,     2899,   'unicum'        ],
    [ 2900,     999999, 'superunicum'   ],
];

sub rating_ident {
    my $dummy = shift;
    my $rating = shift;

    foreach my $entry (@{__PACKAGE__->RATING_MAP}) {
        return $entry->[2] if($rating >= $entry->[0] && $rating <= $entry->[1]);
    }
    return 'unavailable';
}

sub _log {
    my $self = shift;
    my $l    = shift;
    
    $self->__log->$l(join('', '[WR::Provider::WN8]: ', @_));
}

sub debug { shift->_log('debug', @_) }
sub info { shift->_log('info', @_) }
sub error { shift->_log('error', @_) }

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
