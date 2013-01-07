package WR::Res::Achievements;
use Moose;
use namespace::autoclean;
use WR::Localize;

has 'achievements' => (is => 'ro', isa => 'HashRef', builder => '_build_achievements', required => 1);
has '_l' => (is => 'ro', isa => 'WR::Localize', required => 1, default => sub { return WR::Localize->new(type => 'achievements') }, handles => [qw/i18n/]);

sub _build_achievements {
    my $self = shift;

    # decompiled from dossiers/_init_.pyc 
    my @record_names = ('reserved', 'xp', 'maxXP', 'battlesCount', 'wins', 'losses', 'survivedBattles', 'lastBattleTime', 'battleLifeTime', 'winAndSurvived', 'battleHeroes', 'frags', 'maxFrags', 'frags8p', 'fragsBeast', 'shots', 'hits', 'spotted', 'damageDealt', 'damageReceived', 'treesCut', 'capturePoints', 'droppedCapturePoints', 'sniperSeries', 'maxSniperSeries', 'invincibleSeries', 'maxInvincibleSeries', 'diehardSeries', 'maxDiehardSeries', 'killingSeries', 'maxKillingSeries', 'piercingSeries', 'maxPiercingSeries', 'vehTypeFrags', 'warrior', 'invader', 'sniper', 'defender', 'steelwall', 'supporter', 'scout', 'medalKay', 'medalCarius', 'medalKnispel', 'medalPoppel', 'medalAbrams', 'medalLeClerc', 'medalLavrinenko', 'medalEkins', 'medalWittmann', 'medalOrlik', 'medalOskin', 'medalHalonen', 'medalBurda', 'medalBillotte', 'medalKolobanov', 'medalFadin', 'tankExpert', 'titleSniper', 'invincible', 'diehard', 'raider', 'handOfDeath', 'armorPiercer', 'kamikaze', 'lumberjack', 'beasthunter', 'mousebane', 'creationTime', 'maxXPVehicle', 'maxFragsVehicle', 'vehDossiersCut', 'evileye', 'medalRadleyWalters', 'medalLafayettePool', 'medalBrunoPietro', 'medalTarczay', 'medalPascucci', 'medalDumitru', 'markOfMastery', 'company/xp', 'company/battlesCount', 'company/wins', 'company/losses', 'company/survivedBattles', 'company/frags', 'company/shots', 'company/hits', 'company/spotted', 'company/damageDealt', 'company/damageReceived', 'company/capturePoints', 'company/droppedCapturePoints', 'clan/xp', 'clan/battlesCount', 'clan/wins', 'clan/losses', 'clan/survivedBattles', 'clan/frags', 'clan/shots', 'clan/hits', 'clan/spotted', 'clan/damageDealt', 'clan/damageReceived', 'clan/capturePoints', 'clan/droppedCapturePoints', 'medalLehvaslaiho', 'medalNikolas', 'fragsSinai', 'sinai', 'heroesOfRassenay', 'mechanicEngineer', 'tankExpert0', 'tankExpert1', 'tankExpert2', 'tankExpert3','tankExpert4', 'tankExpert5', 'tankExpert6', 'tankExpert7', 'tankExpert8', 'tankExpert9', 'tankExpert10', 'tankExpert11', 'tankExpert12', 'tankExpert13', 'tankExpert14', 'mechanicEngineer0', 'mechanicEngineer1', 'mechanicEngineer2', 'mechanicEngineer3', 'mechanicEngineer4', 'mechanicEngineer5', 'mechanicEngineer6', 'mechanicEngineer7', 'mechanicEngineer8', 'mechanicEngineer9', 'mechanicEngineer10', 'mechanicEngineer11', 'mechanicEngineer12', 'mechanicEngineer13', 'mechanicEngineer14', 'rareAchievements', 'medalBrothersInArms', 'medalCrucialContribution', 'medalDeLanglade', 'medalTamadaYoshio', 'bombardier', 'huntsman', 'alaric', 'sturdy', 'ironMan', 'luckyDevil', 'fragsPatton', 'pattonValley');

    my $h = {};
    my $i = 0;
    foreach my $n (@record_names) {
        $h->{$i++} = $n;
    }
    return $h;
}

sub index_to_idstr {
    my $self = shift;
    my $idx  = shift;
    
    $idx += 0;

    return (defined($self->achievements->{$idx})) ? $self->achievements->{$idx} : $idx;
}

__PACKAGE__->meta->make_immutable;
