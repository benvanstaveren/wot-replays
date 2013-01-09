package WR::Res::Achievements;
use Moose;
use namespace::autoclean;
use WR::Localize;

has 'record_names' => (is => 'ro', isa => 'ArrayRef', required => 1, builder => '_build_record_names');
has 'achievements' => (is => 'ro', isa => 'HashRef', builder => '_build_achievements', lazy => 1);
has 'achievements_by_single' => (is => 'ro', isa => 'HashRef', builder => '_build_achievements_by_single', lazy => 1);
has 'achievements_by_class' => (is => 'ro', isa => 'HashRef', builder => '_build_achievements_by_class', lazy => 1);
has 'achievements_by_battle' => (is => 'ro', isa => 'HashRef', builder => '_build_achievements_by_battle', lazy => 1);

has '_l' => (is => 'ro', isa => 'WR::Localize', required => 1, default => sub { return WR::Localize->new(type => 'achievements') }, handles => [qw/i18n/]);

sub _build_achievements {
    my $self = shift;

    my $i = 0;
    my $h = {};
    foreach my $r (@{$self->record_names}) {
        $h->{$i} = $r;
        $i++;
    }
    return $h;
}

sub _build_record_names {
    # decompiled from dossiers/_init_.pyc 
    return ['reserved', 'xp', 'maxXP', 'battlesCount', 'wins', 'losses', 'survivedBattles', 'lastBattleTime', 'battleLifeTime', 'winAndSurvived', 'battleHeroes', 'frags', 'maxFrags', 'frags8p', 'fragsBeast', 'shots', 'hits', 'spotted', 'damageDealt', 'damageReceived', 'treesCut', 'capturePoints', 'droppedCapturePoints', 'sniperSeries', 'maxSniperSeries', 'invincibleSeries', 'maxInvincibleSeries', 'diehardSeries', 'maxDiehardSeries', 'killingSeries', 'maxKillingSeries', 'piercingSeries', 'maxPiercingSeries', 'vehTypeFrags', 'warrior', 'invader', 'sniper', 'defender', 'steelwall', 'supporter', 'scout', 'medalKay', 'medalCarius', 'medalKnispel', 'medalPoppel', 'medalAbrams', 'medalLeClerc', 'medalLavrinenko', 'medalEkins', 'medalWittmann', 'medalOrlik', 'medalOskin', 'medalHalonen', 'medalBurda', 'medalBillotte', 'medalKolobanov', 'medalFadin', 'tankExpert', 'titleSniper', 'invincible', 'diehard', 'raider', 'handOfDeath', 'armorPiercer', 'kamikaze', 'lumberjack', 'beasthunter', 'mousebane', 'creationTime', 'maxXPVehicle', 'maxFragsVehicle', 'vehDossiersCut', 'evileye', 'medalRadleyWalters', 'medalLafayettePool', 'medalBrunoPietro', 'medalTarczay', 'medalPascucci', 'medalDumitru', 'markOfMastery', 'company/xp', 'company/battlesCount', 'company/wins', 'company/losses', 'company/survivedBattles', 'company/frags', 'company/shots', 'company/hits', 'company/spotted', 'company/damageDealt', 'company/damageReceived', 'company/capturePoints', 'company/droppedCapturePoints', 'clan/xp', 'clan/battlesCount', 'clan/wins', 'clan/losses', 'clan/survivedBattles', 'clan/frags', 'clan/shots', 'clan/hits', 'clan/spotted', 'clan/damageDealt', 'clan/damageReceived', 'clan/capturePoints', 'clan/droppedCapturePoints', 'medalLehvaslaiho', 'medalNikolas', 'fragsSinai', 'sinai', 'heroesOfRassenay', 'mechanicEngineer', 'tankExpert0', 'tankExpert1', 'tankExpert2', 'tankExpert3','tankExpert4', 'tankExpert5', 'tankExpert6', 'tankExpert7', 'tankExpert8', 'tankExpert9', 'tankExpert10', 'tankExpert11', 'tankExpert12', 'tankExpert13', 'tankExpert14', 'mechanicEngineer0', 'mechanicEngineer1', 'mechanicEngineer2', 'mechanicEngineer3', 'mechanicEngineer4', 'mechanicEngineer5', 'mechanicEngineer6', 'mechanicEngineer7', 'mechanicEngineer8', 'mechanicEngineer9', 'mechanicEngineer10', 'mechanicEngineer11', 'mechanicEngineer12', 'mechanicEngineer13', 'mechanicEngineer14', 'rareAchievements', 'medalBrothersInArms', 'medalCrucialContribution', 'medalDeLanglade', 'medalTamadaYoshio', 'bombardier', 'huntsman', 'alaric', 'sturdy', 'ironMan', 'luckyDevil', 'fragsPatton', 'pattonValley'];
}

sub _build_achievements_by_single {
    my $self = shift;

    # from common/dossiers/achievements.pyc
    return { 
        map { $_ => 1 }
        (qw/tankExpert tankExpert0 tankExpert1 tankExpert2 tankExpert3 tankExpert4 tankExpert5 tankExpert6 tankExpert7 tankExpert8
            tankExpert9 tankExpert10 tankExpert11 tankExpert12 tankExpert13 tankExpert14 mechanicEngineer mechanicEngineer0 mechanicEngineer1
            mechanicEngineer2 mechanicEngineer3 mechanicEngineer4 mechanicEngineer5 mechanicEngineer6 mechanicEngineer7 mechanicEngineer8
            mechanicEngineer9 mechanicEngineer10 mechanicEngineer11 mechanicEngineer12 mechanicEngineer13 mechanicEngineer14/)
    }
}

sub is_award {
    my $self = shift;
    my $idx  = shift;

    return ($self->is_battle($idx) || $self->is_class($idx) || $self->is_repeatable($idx)) ? 1 : 0;
}

sub _build_achievements_by_class {
    my $self = shift;

    # from common/dossiers/achievements.pyc
    return { 
        map { $_ => 1 }
        (qw/medalKay medalCarius medalKnispel medalPoppel medalAbrams medalLeClerc medalLavrinenko medalEkins markOfMastery/)
    }
}

sub _build_achievements_by_battle {
    my $self = shift;

    # from common/dossiers/achievements.pyc
    return { 
        map { $_ => 1 }
        (qw/warrior invader sniper defender steelwall supporter scout evileye/)
    }
}

sub is_class {
    my $self = shift;
    my $idx  = shift;
    my $n    = $self->index_to_idstr($idx);

    return (defined($self->achievements_by_class->{$n})) ? 1 : 0;
}

sub is_battle {
    my $self = shift;
    my $idx  = shift;
    my $n    = $self->index_to_idstr($idx);

    return (defined($self->achievements_by_battle->{$n})) ? 1 : 0;
}

sub is_single {
    my $self = shift;
    my $idx  = shift;
    my $n    = $self->index_to_idstr($idx);

    return (defined($self->achievements_by_single->{$n})) ? 1 : 0;
}

sub is_repeatable {
    my $self = shift;
    my $idx  = shift;
    my $n    = $self->index_to_idstr($idx);

    return ($self->is_single($idx) || $self->is_class($idx)) ? 0 : 1;
}

sub index_to_idstr {
    my $self = shift;
    my $idx  = shift;
    
    $idx += 0;

    return (defined($self->achievements->{$idx})) ? $self->achievements->{$idx} : $idx;
}

__PACKAGE__->meta->make_immutable;
