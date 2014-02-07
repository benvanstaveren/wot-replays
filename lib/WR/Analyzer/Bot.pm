package WR::Analyzer::Bot;
use Mojo::Base '-base';

has 'player' => undef;
has 'server' => undef;

=pod
    
=head1 Bot Analysis

A player can be considered to be a bot (or at least perform like one) if any of the following conditions are met; each condition has a score, and the final score dictates the probability of a player being a bot.

=head2 Movement

If the player has not moved his/her vehicle in any direction, but has rotated the gun or turret to point at an enemy that last damaged it; often a symptom of primitive bots: Score 1.0
Since this score is obtained by parsing packets, a decent collection (at least 5) of replays needs to be fed into the analyzer in order for it to deliver a reliable score. 

=head2 Aiming

If the player has more than 50% accuracy at ranges over 200 meters without having entered sniper view (e.g. if the player makes a shot at 300 meters in sniper view, it's most likely a normal player, but shots at that range without sniper view are more difficult to pull off: Score 0.5

If the player has more than 90% of shots landed using auto-aim: Score 0.5

=head2 Overall

If the player has more than an average of 6 battles per hour, for 12 consecutive hours: Score 1.0
If the player win rate is lower than 40%: Score 0.5
If the player survival rate is lower than 10%: Score 0.5

=head1 Final scoring

Score 5:            Most likely a bot
Score 4.5-5.0:      Probably a bot, or a very, very bad player
Score 3.5-4.5:      Most likely a very bad player
Score 2.0-3.5:      Not likely a bot, just a bad player
Score < 2.0:        Not a bot

=cut

1;

