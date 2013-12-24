package WR::Game;
use Mojo::Base '-base';
use WR::Parser; 
use WR::Game::Player;

=pod

    This module emulates the game arena, by keeping track of all player actions. It should let us
    reconstruct the battle result from scratch, meaning that we no longer need the battle result
    either. Having the battle result will still be a requirement for wotreplays.org however.

    Requires that a prepared WR::Parser::Game object is passed in, calling WR::Game->play will start
    the reconstruction, return from this method means results can now be obtained from the players
    list. 

=cut

has '_game'             => undef;

has 'players'           => sub { {} };      # keyed on player ID
has 'clock'             => 0;               # clock
has 'viewmode'          => 'arcade';        # current view mode

sub init {  
    my $self = shift;

    $self->_game->on('player.tank.destroyed' => sub {
        my ($g, $p) = (@_);

        $self->player($p->{destroyed})->health(0);
        $self->player($p->{destroyed})->alive(0);
        $self->player($p->{destroyer})->inc_statistic('frags');
    });
}

sub play { shift->_game->start }

1;
