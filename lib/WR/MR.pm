package WR::MR;
use Moose;
use MongoDB;
use Tie::IxHash;
use File::Slurp;

has '_jobs' => (is => 'ro', isa => 'HashRef', required => 1, lazy => 1, builder => '_build_jobs');
has '_db' => (is => 'ro', isa => 'MongoDB::Database', required => 1, lazy => 1, builder => '_build_db');

sub _build_db {
    my $self = shift;
    
    return MongoDB::Connection->new()->get_database('wot-replays');
}

sub _build_jobs {
    my $self = shift;
    my $dname= (-e '/home/wotreplay/wot-replays/etc/mr') ? '/home/wotreplay/wot-replays/etc/mr' : '/home/ben/projects/wot-replays/etc/mr';
    my $dir;
    my $hash = {};

    opendir($dir, $dname);
    # this should contain directories only
    foreach my $jdname (readdir($dir)) {
        next unless(-d sprintf('%s/%s', $dname, $jdname));
        my $jobdir;
        opendir($jobdir, sprintf('%s/%s', $dname, $jdname));
        foreach my $fragname (readdir($jobdir)) {
            next unless($fragname =~ /\.js$/);
            my $f = $fragname;
            $f =~ s/\.js$//g;
            $hash->{$jdname}->{$f} = read_file(sprintf('%s/%s/%s', $dname, $jdname, $fragname));
        }

        if(-e sprintf('%s/%s/out', $dname, $jdname)) {
            my $out = read_file(sprintf('%s/%s/out', $dname, $jdname));
            chomp($out);
            $hash->{$jdname}->{out} = {
                replace => $out
            }
        }

        closedir($jobdir);
    }
    closedir($dir);
    return $hash;
}

sub map_reduce {
    my $self = shift;
    my $collection = shift;
    my %options = (@_);

    my $cmd = Tie::IxHash->new( 
        "mapreduce" => $collection,
        %options
    );

    return $self->_db->run_command($cmd);
}

sub exec {
    my $self = shift;
    my $type = shift;

    if($self->_jobs->{$type}) {
        my $t = $self->_jobs->{$type};
        my %args;
        for(qw/map finalize reduce out/) {
            $args{$_} = $t->{$_} if(defined($t->{$_}));
        }
        $args{'out'} ||= { 'replace' => $type };
        return $self->map_reduce('replays', %args);
    } else {
        return undef;
    }
}

sub cursor {
    my $self = shift;
    my $type = shift;

    my $res = $self->exec($type);
    return (defined($res) && $res->{ok} == 1) ? $self->_db->get_collection($res->{result})->find() : undef;
}

__PACKAGE__->meta->make_immutable;
