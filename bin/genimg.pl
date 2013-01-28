#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Imager;
use WR::Res::Achievements;
use MongoDB;

$| = 1;

my $mongo  = MongoDB::Connection->new(host => $ENV{'MONGO'} || 'localhost');
my $db     = $mongo->get_database('wot-replays');
my $query  = {};
my $rc = $db->get_collection('replays')->find($query)->sort({ 'site.uploaded_at' => -1 });

while(my $m_data = $rc->next()) {
    my $pv = $m_data->{player}->{vehicle}->{full};
    $pv =~ s/:/-/;

    my $xp = $m_data->{statistics}->{xp};
    if($m_data->{statistics}->{dailyXPFactor10} > 10) {
        $xp .= sprintf(' (x%d)', $m_data->{statistics}->{dailyXPFactor10}/10);
    }

    my $v = $db->get_collection('data.vehicles')->find_one({ _id => $m_data->{player}->{vehicle}->{full} });

    my $t = [];
    my $a = WR::Res::Achievements->new();
    use Data::Dumper;

    foreach my $item (@{$m_data->{statistics}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $str);
    }

    warn 'v: ', $v->{label}, "\n";

    my $i = WR::Imager->new();
    $i->create(
        awards  => $t,
        map     => $m_data->{map}->{id},
        vehicle_name => $v->{label},
        map_name     => $db->get_collection('data.maps')->find_one({ _id => $m_data->{map}->{id} })->{label},
        vehicle => lc($pv),
        result  =>
            ($m_data->{game}->{isWin})
                ? 'victory'
                : ($m_data->{game}->{isDraw})
                    ? 'draw'
                    : 'defeat',
        credits => $m_data->{statistics}->{credits},
        xp      => $xp,
        kills   => $m_data->{statistics}->{kills},
        spotted => $m_data->{statistics}->{spotted},
        damaged => $m_data->{statistics}->{damaged},
        player  => $m_data->{player}->{name},
        clan    => $m_data->{player}->{clan},
        destination => sprintf('%s/%s.png', $ARGV[0], $m_data->{_id}->to_string),
    );
}
