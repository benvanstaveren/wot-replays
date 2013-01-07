package WR::Role::CatalogPo;
use Moose::Role;
use Data::Localize;
use Data::Localize::Gettext;

has 'type' => (is => 'ro', isa => 'Str', required => 1);
has '_path' => (is => 'ro', isa => 'Str', writer => '_set_path');
has '_catalog' => (is => 'ro', isa => 'Data::Localize::Gettext', writer => '_set_catalog');

sub BUILD {
    my $self = shift;

    $self->_set_path((-e '/home/wotreplay/wot-replays/etc/res') 
        ? '/home/wotreplay/wot-replays/etc/res'
        : sprintf('%s/projects/wot-replays/etc/res', $ENV{HOME}));
    $self->_set_catalog(Data::Localize::Gettext->new(path => sprintf('%s/*.po', $self->_path)));
}

sub i18n {
    my $self = shift;
    my $key  = shift;

    return $self->_catalog->localize_for(lang => $self->type, id => $key);
}

no Moose::Role;
1;
