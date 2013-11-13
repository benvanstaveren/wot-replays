package WR::Provider::WN7;
use Mojo::Base '-base';
use Try::Tiny qw/try catch/;
use Data::Dumper;

has 'db'    =>  undef; # db from app

sub get_class_from_rating {
    my $self = shift;
    my $rating = shift;
    my $class_map = [
        [ 0, 499, 'verybad' ],
        [ 500, 699, 'bad' ],
        [ 700, 899, 'belowaverage' ],
        [ 900, 1099, 'average' ],
        [ 1100, 1349, 'good' ],
        [ 1350, 1499, 'verygood' ],
        [ 1500, 1699, 'great' ],
        [ 1700, 1999, 'unicum' ],
        [ 2000, 99999, 'superunicum' ]
    ];

    foreach my $entry (@$class_map) {
        return $entry->[2] if($rating >= $entry->[0] && $rating <= $entry->[1]);
    }
    return 'unknown';
}

sub fetch_one {
    my $self    = shift;
    my $id      = shift;
    my $cb      = shift;

    $self->db->collection('player.stats')->find_one({ _id => $id + 0 } => sub {
        my ($coll, $err, $doc) = (@_);

        warn 'err: ', $err, "\n" and $cb->(undef) and return if(defined($err));
        warn 'no doc', "\n" and $cb->(undef) and return unless(defined($doc));

        my $wn7_overall = $self->calc_wn7($doc->{stats}->{data});
        my $wn7_class   = $self->get_class_from_rating($wn7_overall);

        $cb->({ 
            class => $wn7_class,
            data  => { overall => $wn7_overall },
            available => Mango::BSON::bson_true,
        });
    });
}


use constant E => 2.71828;

sub min {
    my $self = shift;
    my $val  = shift;
    my $cap  = shift;

    return ($val <= $cap) ? $val : $cap;
}

sub get_average_tier {
    my $self = shift;
    my $data = shift;

    my $tier  = 0;
    my $total = 0;

    foreach my $vehicle (@{$data->{vehicles}}) {
        my $bcount = $vehicle->{battle_count};
        $tier += $vehicle->{level} for(1..$bcount);
        $total += $bcount;
    }
    
    return $self->safe_div($tier, $total);
}

sub safe_div {
    my $self = shift;
    my $a    = shift;
    my $b    = shift;
    my $r    = 0;

    try {
        $r = $a / $b;
    } catch {
        $r = 0;
    };
    return $r;
}

sub pow {
    my $self = shift;
    my $a    = shift;
    my $b    = shift;

    return $a ** $b;
}

sub calc_wn7 {
    my $self = shift;
    my $data = shift;

    my $average_tier = sprintf('%.2f', $self->get_average_tier($data)) + 0.0;
    my $games_played = $data->{summary}->{battles_count} + 0;
    my $frags        = sprintf('%.2f', $self->safe_div($data->{battles}->{frags}, $games_played)) + 0.0;
    my $damage       = sprintf('%.2f', $self->safe_div($data->{battles}->{damage_dealt}, $games_played)) + 0.0;
    my $spotted      = sprintf('%.2f', $self->safe_div($data->{battles}->{spotted}, $games_played)) + 0.0;
    my $defense      = sprintf('%.2f', $self->safe_div($data->{battles}->{dropped_capture_points}, $games_played)) + 0.0;
    my $winrate      = sprintf('%.2f', $self->safe_div(100, $self->safe_div($data->{summary}->{battles_count}, $data->{summary}->{wins}))) + 0.0;

    warn 'average_tier: ', $average_tier, "\n";
    warn 'games_played: ', $games_played, "\n";
    warn 'frags: ', $frags, "\n";
    warn 'damage: ', $damage, "\n";
    warn 'spotted: ', $spotted, "\n";
    warn 'defense: ', $defense, "\n";
    warn 'winrate: ', $winrate, "\n";

=pod 

wn7 formula

1240-1040/(MIN(TIER,6))^0.164)*FRAGS
+DAMAGE*530/(184*e^(0.24*TIER)+130)
+SPOT*125*MIN(TIER, 3)/3
+MIN(DEF,2.2)*100
+((185/(0.17+e^((WINRATE-35)*-0.134)))-500)*0.45
-[(5 - MIN(TIER,5))*125] / [1 + e^( ( TIER - (GAMESPLAYED/220)^(3/TIER) )*1.5 )]


phalynx implementation

    $mintier = 5-$getdata['tier'];  
    $efficiency_wnx = (POW(1240-1040/(MIN($getdata['tier'],6)),0.164))*$getdata['frags'];
    $efficiency_wnx += $getdata['avg_damage_dealt']*530/(184*POW(2.71828,(0.24*$getdata['tier']))+130);
    $efficiency_wnx += $getdata['avg_spotted']*125*MIN($getdata['tier'], 3)/3;
    $efficiency_wnx += MIN($getdata['avg_defence_points'],2.2)*100;
    $efficiency_wnx += ((185/(0.17+POW(2.71828,((50-35)*-0.134))))-500)*0.45;
    $efficiency_wnx -= ((MIN($mintier,5))*125) / (1 + POW(2.71828, ( ( $getdata['tier'] - POW(($getdata['battles']/220),(3/$getdata['tier'])) )*1.5 )));


=cut
    # this one comes out wrong, somehow... 

    return -1;
}

1;
