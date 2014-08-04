package Rube::Language;
use Mojo::Base 'Rube::Base';
use File::Path qw/make_path/;

sub _build {
    my $self      = shift;
    return $self;
}

sub install {
    my $self = shift;
    my $db   = shift;

    my $lang_path = sprintf('%s/res/text/lc_messages', $self->wot_folder);
    my $dest      = [ sprintf('%s/etc/res/raw/%s/lang', $self->site_folder, $self->version), sprintf('%s/lang/wg/common/%s', $self->site_folder, $self->version) ];


    foreach my $d (@$dest) {
        $self->info('Extracting language files from ', $lang_path, ' to ', $d);
        make_path($d) unless(-e $d);
        opendir(my $dir, $lang_path);
        foreach my $file (readdir($dir)) {
            next unless($file =~ /\.mo$/);
            system('cp', sprintf('%s/%s', $lang_path, $file), sprintf('%s/%s', $d, $file));
            my $newfile = $file;
            $newfile =~ s/\.mo$/\.po/;
            system('msgunfmt', sprintf('%s/%s', $d, $file), '-o', sprintf('%s/%s', $d, $newfile));
            unlink(sprintf('%s/%s', $d, $file));
        }
    }
}

1;
