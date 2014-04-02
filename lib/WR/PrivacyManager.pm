package WR::PrivacyManager;
use Mojo::Base '-base';

has 'user'      => undef;
has 'replay'    => undef; # not always here 

use constant PRIVACY_PUBLIC         => 0;
use constant PRIVACY_UNLISTED       => 1;
use constant PRIVACY_PRIVATE        => 2;
use constant PRIVACY_CLAN           => 3;
use constant PRIVACY_PARTICIPANTS   => 4;
use constant PRIVACY_TEAM           => 5;

sub for_query {
    my $self = shift;

    my $priv = [
        $self->_privacy_public,
    ];
    push(@$priv, $self->_privacy_recorder) if(defined($self->user) && defined($self->user->{player_name}));
    push(@$priv, $self->_privacy_clan) if(defined($self->user) && defined($self->user->{clan}));
    push(@$priv, $self->_privacy_participants) if(defined($self->user) && defined($self->user->{player_name}));
    push(@$priv, $self->_privacy_team) if(defined($self->user) && defined($self->user->{player_name}));
    return $priv;
}

sub _privacy_public {
    my $self = shift;

    return {
        'site.visible' => Mango::BSON::bson_true,
    };
}

sub _privacy_recorder {
    my $self = shift;

    return {
        'site.visible'       => Mango::BSON::bson_false,
        'site.privacy'       => 2,
        'game.recorder.name' => $self->user->{player_name},
        'game.server'        => $self->user->{player_server},
    };
}

sub _privacy_clan {
    my $self = shift;

    return {
        'site.visible'       => Mango::BSON::bson_false,
        'site.privacy'       => 3,
        'game.server'        => $self->user->{player_server},
        'game.recorder.clan' => $self->user->{clan}->{abbreviation},
    };
}

sub _privacy_participants {
    my $self = shift;

    return {
        'site.visible'      => Mango::BSON::bson_false,
        'site.privacy'      => 4,
        'game.server'       => $self->user->{player_server},
        'involved.players'  => $self->user->{player_name},
    };
}

sub _privacy_team {
    my $self = shift;

    return {
        'site.visible'      => Mango::BSON::bson_false,
        'site.privacy'      => 4,
        'game.server'       => $self->user->{player_server},
        'involved.team'     => $self->user->{player_name},
   };
}

1;
