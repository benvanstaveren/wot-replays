#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Imager;
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

    my $i = WR::Imager->new();
    $i->create(
        map     => $m_data->{map}->{id},
        vehicle => lc($pv),
        result  =>
            ($m_data->{game}->{isWin})
                ? 'victory'
                : ($m_data->{game}->{isDraw})
                    ? 'draw'
                    : 'defeat',
        credits => $m_data->{statistics}->{credits},
        xp      => $m_data->{statistics}->{xp},
        kills   => $m_data->{statistics}->{kills},
        spotted => $m_data->{statistics}->{spotted},
        damaged => $m_data->{statistics}->{damaged},
        player  => $m_data->{player}->{name},
        clan    => $m_data->{player}->{clan},
        destination => sprintf('%s/%s.png', $ARGV[0], $m_data->{_id}->to_string),
    );
}
