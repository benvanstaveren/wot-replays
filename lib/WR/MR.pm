package WR::MR;
use Moose;
use Tie::IxHash;
use Try::Tiny;
use File::Slurp qw/read_file/;
use Data::Dumper;

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);
has 'map' => (is => 'ro', isa => 'Str', writer => '_set_map');
has 'finalize' => (is => 'ro', isa => 'Str', writer => '_set_finalize');
has 'reduce' => (is => 'ro', isa => 'Str', writer => '_set_reduce');
has 'folder' => (is => 'ro', isa => 'Str');
has 'cond'   => (is => 'ro', isa => 'HashRef', default => sub { {} });

sub BUILD {
    my $self = shift;

    return unless(defined($self->folder));

    die 'No map.js', "\n" unless(-e sprintf('%s/map.js', $self->folder));
    die 'No reduce.js', "\n" unless(-e sprintf('%s/reduce.js', $self->folder));

    my $finalize;
    $finalize = read_file(sprintf('%s/finalize.js', $self->folder)) if(-e sprintf('%s/finalize.js', $self->folder));

    my $map = read_file(sprintf('%s/map.js', $self->folder));
    my $reduce = read_file(sprintf('%s/reduce.js', $self->folder));

    $self->_set_map($map);
    $self->_set_reduce($reduce);
    $self->_set_finalize($finalize) if(defined($finalize));
}

sub execute {
    my $self = shift;
    my $name = shift || 'replays';
    my $out  = shift;

    my $job = Tie::IxHash->new(
        mapreduce => $name,
        map       => $self->map,
        reduce    => $self->reduce,
        query     => $self->cond,
        out       => {
            replace => $out,
        }
    );
    return $self->db->run_command($job);
}

__PACKAGE__->meta->make_immutable;
