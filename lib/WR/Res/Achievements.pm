package WR::Res::Achievements;
use Moose;
use namespace::autoclean;

with 'WR::Role::Catalog';

has '_idlist' => (is => 'ro', 'isa' => 'ArrayRef', required => 1, default => sub {
    [qw(warrior invader sniper defender steelwall supporter scout)],
    });

has '_epic_idlist' => (is => 'ro', 'isa' => 'ArrayRef', required => 1, default => sub {
    [qw(medalWittman medalOrlik medalOskin medalHalonen medalBurda medalBillotte medalKolobanov medalFadin invincible diehard raider kamikaze sniper killing piercing)],
    });

has 'epics' => (is => 'ro', isa => 'HashRef', default => sub {
    {
    },
});

has 'achievements' => (is => 'ro', isa => 'HashRef', default => sub {
    {
        39  =>  'supporter',
        40  =>  'scout',
        72  =>  'evileye',
    },
});

sub index_to_epic_idstr {
    my $self = shift;
    my $idx  = shift;

    return $self->_epic_idlist->[$idx] || sprintf('unknown:%d', $idx);
}

sub index_to_idstr {
    my $self = shift;
    my $idx  = shift;
    
    $idx += 0;

    return $self->achievements->{$idx};
}

__PACKAGE__->meta->make_immutable;
