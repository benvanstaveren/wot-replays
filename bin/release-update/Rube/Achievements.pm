package Rube::Achievements;
use Mojo::Base 'Rube::Base';
use File::Slurp qw/read_file/;
use Data::Dumper;

has 'achievements'  => sub { [] };

sub _build {
    my $self = shift;

    # load achievements out of 
    # res_u_folder/common/dossiers1/__init__.pyc_dis
    my @content = read_file(sprintf('%s/common/dossiers1/__init__.pyc_dis', $self->res_u_folder));

    foreach my $line (@content) {
        if($line =~ /^RECORD_NAMES = (.*)/) {
            my @record_names = eval($1);
            unless($@) {
                my $i = 0;
                foreach my $e (@record_names) {
                    push(@{$self->achievements}, { 
                        _id     => $i++,
                        name    => $e,
                    });
                }
            }
        }
    }
    return $self;
}

sub install {
    my $self = shift;
    my $db   = shift;

    $db->collection('data.achievements')->drop();
    foreach my $a (@{$self->achievements}) {
        $db->collection('data.achievements')->save($a);
        $self->info('Stored achievement ', $a->{name}, ' with ID ', $a->{_id});
    }
}

1;
