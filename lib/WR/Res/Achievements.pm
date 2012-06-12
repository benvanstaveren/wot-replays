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

sub index_to_epic_idstr {
    my $self = shift;
    my $idx  = shift;

    return $self->_epic_idlist->[$idx];
}

sub index_to_idstr {
    my $self = shift;
    my $idx  = shift;

    return $self->_idlist->[$idx - 1];
}

__PACKAGE__->meta->make_immutable;
