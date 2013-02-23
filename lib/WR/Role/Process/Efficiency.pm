package WR::Role::Process::Efficiency;
use Moose::Role;
use Try::Tiny qw/catch try/;

sub get_player_id {
    my $self = shift;
    my $res  = shift;
    my $name = shift;

    foreach my $id (keys(%{$res->{players}})) {
        return $id if($res->{players}->{$id}->{name} eq $name);
    }
    return undef;
}

sub safe_div {
    my $self = shift;
    my $a    = shift;
    my $b    = shift;

    return ($a > 0 && $b > 0) ? $a / $b : 0;
}

sub calc_eff {
    my $self = shift;
    my $pdata = shift;

    return 0 if($pdata->{b} < 1);

    my $TIER    = $pdata->{lvl};
    my $FRAGS   = $self->safe_div($pdata->{frg}, $pdata->{b});
    my $DAMAGE  = $self->safe_div($pdata->{dmg}, $pdata->{b});
    my $SPOT    = $self->safe_div($pdata->{spo}, $pdata->{b});
    my $CAP     = $self->safe_div($pdata->{cap}, $pdata->{b});
    my $DEF     = $self->safe_div($pdata->{def}, $pdata->{b});

    my $eff = sprintf('%.0f', (
        $DAMAGE * (10 / ($TIER + 2)) * (0.23 + 2 * $TIER / 100) +
        $FRAGS * 250 + 
        $SPOT * 150 +
        log($CAP+1) / log(1.732) * 150 +
        $DEF * 150
        ) / 10) * 10;
    return $eff;
}

sub calc_wn {
    my $self = shift;
    my $pdata = shift;

    my $TIER    = $pdata->{lvl};
    my $TIER_N  = ($TIER > 6) ? 6 : $TIER;
    my $FRAGS   = $self->safe_div($pdata->{frg}, $pdata->{b});
    my $DAMAGE  = $self->safe_div($pdata->{dmg}, $pdata->{b});
    my $SPOT    = $self->safe_div($pdata->{spo}, $pdata->{b});
    my $DEF     = $self->safe_div($pdata->{def}, $pdata->{b});
    my $WINRATE = $self->safe_div($pdata->{w}, $pdata->{b}) * 100;

    my $wn6;
    $wn6 = try {
        sprintf('%.0f', 
            (1240 - 1040 / $TIER_N ** 0.164) * $FRAGS +
            $DAMAGE * 530 / (184 * exp(0.24 * $TIER) + 130) +
            $SPOT * 125 +
            $DEF * 100 +
            ((185 / (0.17 + exp(($WINRATE - 35) * -0.134))) - 500) * 0.45 +
            (6 - $TIER_N) * -60);
    } catch {
        $self->app->log->error('calc_wn: exception: ' . $_);
        $wn6 = 1;
    };
    return ($wn6 > 1) ? $wn6 : 1;
}

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    $res->{efficiency} = {};

    if(my $playerid = $self->get_player_id($res => $res->{player}->{name})) {
        if(my $data = $self->model('xvmp.playerdata')->find_one({ _id => $playerid + 0 })) {
            $res->{efficiency}->{$res->{player}->{name}} = {
                xvm => $self->calc_eff($data),
                wn6 => $self->calc_wn($data),
            };
        } else {
            $self->model('xvmp.missing')->save({ _id => $playerid + 0, l => time() });
        }
    }
    return $res;
};

no Moose::Role;
1;
