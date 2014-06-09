package Rube::Language;
use Mojo::Base 'Rube::Base';

sub _build {
    my $self      = shift;
    return $self;
}

sub install {
    my $self = shift;
    my $db   = shift;

    my $lang_path = sprintf('%s/res/text/lc_messages', $self->wot_folder);
    my $dest      = sprintf('%s/etc/res/raw/%s/lang', $self->site_folder, $self->version);

    $self->info('Extracting language files from ', $lang_path, ' to ', $dest);
}

1;
