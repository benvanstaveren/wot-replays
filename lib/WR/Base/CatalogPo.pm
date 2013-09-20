package WR::Base::CatalogPo;
use Mojo::Base '-base';
use Data::Localize;
use Data::Localize::Gettext;

has 'type'      => undef;
has '_path'     => undef;
has '_catalog'  => undef;

sub new {
    my $package = shift;
    my $self = $package->SUPER::new(@_);
    
    bless($self, $package);

    $self->path((-e '/home/wotreplay/site/etc/res') 
        ? '/home/wotreplay/site/etc/res'
        : sprintf('%s/projects/wot-replays/etc/res', $ENV{HOME}));
    $self->catalog(Data::Localize::Gettext->new(path => sprintf('%s/*.po', $self->_path)));
}

sub i18n {
    my $self = shift;
    my $key  = shift;

    return $self->_catalog->localize_for(lang => $self->type, id => $key);
}

1;
