package WR::Analyzer::Bot;
use Mojo::Base '-base';

has 'player' => undef;
has 'server' => undef;
has 'ua'     => undef;
has 'token'  => undef;

=pod
    
=head1 Bot Analysis

A player can be considered to be a bot (or at least perform like one) if any of the following conditions are met; each condition has a score, and the final score dictates the probability of a player being a bot.

=head2 Win Rate

If the players' win rate is below 50%: Score 0.25
If the players' win rate is below 45%: Score 0.50
If the players' win rate is below 40%: Score 1.00

=head2 K/D ratio

If the players' K/D ratio is below 0.80: Score 0.25
If the players' K/D ratio is below 0.50: Score 0.50
If the players' K/D ratio is below 0.25: Score 1.00

=head2 Damage ratio

If the players' damage ratio is below 0.80: Score 0.25
If the players' damage ratio is below 0.50: Score 0.50
If the players' damage ratio is below 0.25: Score 1.00

=head2 Accuracy

If the players' hit ratio is below 60%: Score 0.25
If the players' hit ratio is below 50%: Score 0.50
If the players' hit ratio is below 40%: Score 1.00

=head2 Total battles v.s. creation time

=head2 Average experience

=head1 Final scoring

Score           Result
--------------------------------
4.00            Most likely a bot
2.00            Probably a bot, or just a really bad player
1.00            Probably not a bot, just an average player

=cut

sub analyze {
    my $self = shift;
    my $cb   = shift;
    my $url  = sprintf('http://statterbox.com/api/v1/%s/summary?p=%s&s=%s',
        $self->token,
        $self->player,
        $self->server
    );

    $self->ua->get($url => sub {
        my ($ua, $tx) = (@_);

        if(my $res = $tx->success) {
            $self->perform_analysis($res->json->{result} => $cb);
        } else {
            $cb->($self, 'no transaction', undef);
        }
    });
}

sub perform_analysis {
    my $self = shift;
    my $data = shift;
    my $cb   = shift;
    my $score = 0;

    my $battles = $data->{info}->{statistics}->{all}->{battles};
    my $kills   = $data->{info}->{statistics}->{all}->{frags};
    my $surv    = $data->{info}->{statistics}->{all}->{survived_battles};
    my $damage  = $data->{info}->{statistics}->{all}->{damage_dealt};
    my $drec    = $data->{info}->{statistics}->{all}->{damage_received};
    my $acc     = $data->{info}->{statistics}->{all}->{hits_percents}+0;
    my $wins    = $data->{info}->{statistics}->{all}->{wins};

    my $kd_ratio = ($kills > 0 && ($battles - $surv) > 0) ? sprintf('%.2f', $kills / ($battles - $surv)) : 0;
    my $dm_ratio = ($damage > 0 && $drec > 0) ? sprintf('%.2f', $damage / $drec) : 0;
    my $wr       = ($battles > 0 && $wins > 0) ? sprintf('%.2f', 100/($battles/$wins)) : 0;

    warn 'kd: ', $kd_ratio, ' dm: ', $dm_ratio, ' wr: ', $wr, ' acc: ', $acc, "\n";

    $score += ($kd_ratio < 0.25)
        ? 1.00
        : ($kd_ratio < 0.50)
            ? 0.50
            : ($kd_ratio < 0.80) 
                ? 0.25
                : 0.00;

    $score += ($dm_ratio < 0.25)
        ? 1.00
        : ($dm_ratio < 0.50) 
            ? 0.50
            : ($dm_ratio < 0.80)
                ? 0.25
                : 0.00;

    $score += ($acc < 40)
        ? 0.25
        : ($acc < 50)
            ? 0.50
            : ($acc < 60)
                ? 1.00
                : 0.00;

    $score += ($wr < 40)
        ? 1.00
        : ($wr < 45)
            ? 0.50
            : ($wr < 50)
                ? 0.25
                : 0.00;

    $cb->($self, undef, ($score > 0) ? int(100/(4/$score)) : 0);
}

1;

