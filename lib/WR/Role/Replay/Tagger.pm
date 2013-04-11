package WR::Role::Replay::Tagger;
use Moose::Role;

sub tag_replay {
    my $self   = shift;
    my $replay = shift;

    # get the list of players on the player team sorted by earned base xp 
    #
    # add a tag: 'carried' if:
    #   -   player is #1 
    #   -   xp for player #2 * 1.50 < player xp 


    # if total damage done by player > 50% of all damage done to enemy players
    # add tag: destroyer




}



no Moose::Role;
1;
