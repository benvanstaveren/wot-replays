package WR::Offline::Process;
use Moose;
use boolean;
use WR::Process;
use WR::Imager;
use FileHandle;
use POSIX();
use Try::Tiny qw/try catch/;

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);

sub r_error {
    my $self = shift;
    my $msg  = shift;
    my $file = shift;

    unlink($file);

    return { ok => 0, error => $msg };
}

sub nv {
    my $self = shift;
    my $v    = shift;

    $v =~ s/\w+//g;
    $v += 0;
    return $v;
}

sub process {
    my $self  = shift;
    my $jobid = shift;

    if(my $job = $self->db->get_collection('job.process')->find_one({ _id => bless({ value => $jobid }, 'MongoDB::OID' ) })) {
        try {
            $self->_process($job);
        } catch {
            unlink($job->{file});
        };
    } else {
        return { ok => 0, error => 'No job found' };
    }
}

sub _process {
    my $self = shift;
    my $job  = shift;
    my $replay_file = $job->{file};

    try {
        my $p = WR::Process->new(
            file    => $job->{file},
            db      => $self->db,
            bf_key  => $self->bf_key,
        );
        $m_data = $p->process();
    } catch {
        unlink($job->{file});
        $pe = $_;
    };

    return $self->r_error(sprintf('Error parsing replay: %s', $pe), $replay_file) if($pe);
    return $self->r_error('That replay seems to exist already', $replay_file) if($self->db('wot-replays')->get_collection('replays')->find_one({ replay_digest => $m_data->{replay_digest} }));
    return $self->r_error('That replay seems to be coming from the public test server, we can\'t store those at the moment', $replay_file) if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);
    return $self->r_error(q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player|, $replay_file) if($m_data->{player}->{id} == 0);

    my $rv = $self->nv($m_data->{version});

    return $self->r_error(q|Sorry, but this replay is from an World of Tanks version that is no longer supported|, $replay_file) if($rv < $self->nv('0.8.2'));

    my $filename = $replay_file;
    $filename =~ s/.*\\//g if($filename =~ /\\/);
    $filename =~ s/.*\///g if($filename =~ /\//);

    $m_data->{file} = $filename;
    $m_data->{site} = {
        description => $job->{description} || undef,
        uploaded_at => time(),
        uploaded_by => (defined($job->{user})) ? bless({ value => $job->{user} }, 'MongoDB::OID') : undef,
        visible     => ($job->{hide} == 1) ? false : true,
    };

    if(defined($job->{site_extra})) {
        foreach my $k (keys(%{$job->{site_extra}})) {
            $m_data->{site}->{$k} = $job->{site_extra}->{$k};
        }
    }

    $self->db('wot-replays')->get_collection('replays')->save($m_data, { safe => 1 });

    try {
        my $pv = $m_data->{player}->{vehicle}->{full};
        $pv =~ s/:/-/;

        my $xp = $m_data->{statistics}->{xp};
        if($m_data->{statistics}->{dailyXPFactor10} > 10) {
            $xp .= sprintf(' (x%d)', $m_data->{statistics}->{dailyXPFactor10}/10);
        }

        my $i = WR::Imager->new();
        $i->create(
            map     => $m_data->{map}->{id},
            vehicle => lc($pv),
            result  => 
                ($m_data->{game}->{isWin})
                    ? 'victory'
                    : ($m_data->{game}->{isDraw})
                        ? 'draw'
                        : 'defeat',
            credits => $m_data->{statistics}->{credits},
            xp      => $xp,
            kills   => $m_data->{statistics}->{kills},
            spotted => $m_data->{statistics}->{spotted},
            damaged => $m_data->{statistics}->{damaged},
            player  => $m_data->{player}->{name},
            clan    => $m_data->{player}->{clan},
            destination => sprintf('%s/%s.png', $self->stash('config')->{paths}->{replays}, $m_data->{_id}->to_string),
        );
    } catch {
        # not catastrophic if this isn't generated, we'll pawn it off into something else later
    };
}

1;
