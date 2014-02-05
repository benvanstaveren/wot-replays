package WR::Daemon::Process;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Log;
use Mango;
use Mango::BSON;
use WR;
use WR::Process::Full;
use WR::Process::ChatReader;
use Data::Dumper;
use Carp qw/cluck/;

has 'config'    => sub { {} };
has 'skip_wn7'  => 0;
has 'log'       => undef;
has 'mango'     => sub { shift->get_mango };
has 'db'        => sub {
    my $self = shift;
    return $self->mango->db($self->config->{mongodb}->{database});
};

sub get_mango {
    my $self = shift;
    return Mango->new($self->config->{mongodb}->{host});
}

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('debug', @_) }
sub error   { shift->_log('debug', @_) }

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join(' ', '[', $$, '] ', @_);

    $self->log->$l($m);
}

sub job_error {
    my $self    = shift;
    my $job     = shift;
    my $error   = shift;

    $self->db->collection('jobs')->update({ _id => $job->{_id} }, {
        '$set' => {
            complete => Mango::BSON::bson_true,
            status   => -1,
            error    => $error,
        }
    });
}

sub job_status {
    my $self    = shift;
    my $job     = shift;
    my $status  = shift;
    my $current;
    my $u = 0;

    $current = $job->{status_text};

    my $new = [];

    foreach my $e (@$current) {
        if($e->{id} eq $status->{id}) {
            push(@$new, $status);
            $u++;
        } else {
            push(@$new, $e);
        }
    }

    push(@$new, $status) unless($u > 0);

    $self->db->collection('jobs')->update({ _id => $job->{_id} }, {
        '$set' => {
            status_text => $new,
        }
    });

    $job->{status_text} = $new; # wonder if this works...
}

sub process_chatreader {
    my $self = shift;
    my $job  = shift;

    # chat reading will have some additional info going on
    my $o = WR::Process::ChatReader->new(
        bf_key          => join('', map { chr(hex($_)) } (split(/\s/, $self->config->{wot}->{bf_key}))),
        file            => $job->{data}->{file},
        log             => $self->log,
    );

    # no need for job updates, but we do want to mark it complete 

    $o->on('message' => sub {
        my ($o, $text) = (@_);
        $self->emit('message' => $text); 
    });

    $o->process;

    $self->emit('finished');

    unlink($job->{data}->{file});
    $self->db->collection('jobs')->remove({ _id => $job->{_id} });
}

sub process_job {
    my $self = shift;
    my $job = shift;

    if(!$job->{reprocess}) {
        if($self->db->collection('replays')->find({ digest => $job->{_id} })->count() > 0) {
            $self->job_error($job, 'Looks like that replay has been uploaded already...');
            return undef;
        }
    }


    my $o = WR::Process::Full->new(
        bf_key          => join('', map { chr(hex($_)) } (split(/\s/, $self->config->{wot}->{bf_key}))),
        banner_path     => $self->config->{paths}->{banners},
        packet_path     => $self->config->{paths}->{packets},
        mango           => $self->get_mango,
        file            => $job->{data}->{file},
        log             => $self->log,
        skip_wn7        => $self->skip_wn7,
        );

    $o->on('state.prepare.start' => sub {
        $self->job_status($job, {
            id      =>  'prepare',
            text    =>  'Preparing replay',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.prepare.finish' => sub {
        $self->job_status($job, {
            id      =>  'prepare',
            text    =>  'Preparing replay',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_true,
        });
    });
    $o->on('state.streaming.start' => sub {
        my ($o, $total) = (@_);

        $self->job_status($job, {
            id      =>  'streaming',
            text    =>  'Extracting packets',
            type    =>  'progress',
            count   =>  0,
            total   =>  $total,
            perc    =>  0,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.streaming.progress' => sub {
        my ($o, $d) = (@_);
        my $perc;

        if($d->{count} > 0 && $d->{total} > 0) {
            $perc = sprintf('%.0f', (100/($d->{total}/$d->{count})));
        } else {
            $perc = 0;
        }

        $self->job_status($job, {
            id      =>  'streaming',
            text    =>  'Extracting packets',
            type    =>  'progress',
            count   =>  $d->{count},
            total   =>  $d->{total},
            perc    =>  $perc,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.streaming.finish' => sub {
        my ($o, $total) = (@_);
        $self->job_status($job, {
            id      =>  'streaming',
            text    =>  'Extracting packets',
            type    =>  'progress',
            count   =>  $total,
            total   =>  $total,
            perc    =>  100,
            done    =>  Mango::BSON::bson_true,
        });
    });
    $o->on('state.generatebanner.start' => sub {
        $self->job_status($job, {
            id      => 'generatebanner',
            text    => 'Generating preview banner',
            type    => 'spinner',
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.generatebanner.finish' => sub {
        $self->job_status($job, {
            id      => 'generatebanner',
            text    => 'Generating preview banner',
            type    => 'spinner',
            done    =>  Mango::BSON::bson_true,
        });
    });
    $o->on('state.packet.save.start' => sub {
        my ($o, $total) = (@_);

        $self->job_status($job, {
            id      => 'packetsave',
            text    => 'Storing replay packets to disk',
            type    => 'progress',
            count   => 0,
            total   => $total,
            perc    => 0,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.packet.save.progress' => sub {
        my ($o, $d) = (@_);
        my $perc;

        if($d->{count} > 0 && $d->{total} > 0) {
            $perc = sprintf('%.0f', (100/($d->{total}/$d->{count})));
        } else {
            $perc = 0;
        }

        $self->job_status($job, {
            id      => 'packetsave',
            text    => 'Storing replay packets to disk',
            type    =>  'progress',
            count   =>  $d->{count},
            total   =>  $d->{total},
            perc    =>  $perc,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.packet.save.finish' => sub {
        my ($o, $total) = (@_);
        $self->job_status($job, {
            id      => 'packetsave',
            text    => 'Storing replay packets to disk',
            type    =>  'progress',
            count   =>  $total,
            total   =>  $total,
            perc    =>  100,
            done    =>  Mango::BSON::bson_true,
        });
    });
    $o->on('state.wn7.start' => sub {
        my ($o, $total) = (@_);

        $self->job_status($job, {
            id      =>  'wn7',
            text    =>  'Fetching WN8 data from Statterbox',
            type    =>  'progress',
            count   =>  0,
            total   =>  $total,
            perc    =>  0,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.wn7.progress' => sub {
        my ($o, $d) = (@_);
        my $perc;

        if($d->{count} > 0 && $d->{total} > 0) {
            $perc = sprintf('%.0f', (100/($d->{total}/$d->{count})));
        } else {
            $perc = 0;
        }

        $self->job_status($job, {
            id      =>  'wn7',
            text    =>  'Fetching WN8 data from Statterbox',
            type    =>  'progress',
            count   =>  $d->{count},
            total   =>  $d->{total},
            perc    =>  $perc,
            done    =>  Mango::BSON::bson_false,
        });
    });
    $o->on('state.wn7.finish' => sub {
        my ($o, $total) = (@_);
        $self->job_status($job, {
            id      =>  'wn7',
            text    =>  'Fetching WN8 data from Statterbox',
            type    =>  'progress',
            count   =>  $total,
            total   =>  $total,
            perc    =>  100,
            done    =>  Mango::BSON::bson_true,
        });
    });

    if(my $replay = $o->process( ($job->{reprocess}) ? $job->{replayid} : undef)) {
        if($o->has_error > 0) {
            my $err = $o->error;
            $self->debug('Error processing: ', $err);
            $self->job_error($job, 'Error during parsing: ' . $err);
            return undef;
        }
        
        $self->debug('no error yet, yay');

        if($job->{reprocess}) {
            my $oreplay = $self->db->collection('replays')->find_one({ digest => $job->{_id}}); # that's the way to find it, innit?
            $replay->{site} = $oreplay->{site};
        }

        $self->job_status($job, {
            id      =>  'final',
            text    =>  'Saving replay',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        });
        
        if(!defined($replay->{game}->{version_numeric}) || (defined($replay->{game}->{version_numeric}) && $replay->{game}->{version_numeric} < $self->config->{wot}->{min_version})) {
            unlink($job->{file});
            $self->job_error($job, 'That replay is from an older version of World of Tanks which we cannot process...');
            return undef;
        } elsif($replay->{game}->{version_numeric} > $self->config->{wot}->{version_numeric}) {
            unlink($job->{file});
            $self->job_error($job, 'That replay seems to be coming from the test server, we cannot process those yet...');
            return undef;
        } else {
            if(!$job->{reprocess}) {
                $replay->{digest} = $job->{_id};
                $replay->{site}->{visible} = Mango::BSON::bson_false if($job->{data}->{visible} < 1);
                $replay->{site}->{privacy} = $job->{data}->{privacy};
                $replay->{site}->{description} = (defined($job->{data}->{desc}) && length($job->{data}->{desc}) > 0) ? $job->{data}->{desc} : undef;
                $replay->{file} = $job->{data}->{file_base}; 

                # fix privacy for clan war replays
                if($replay->{game}->{bonus_type} == 5) {
                    $replay->{site}->{visible} = Mango::BSON::bson_false;
                    $replay->{site}->{privacy} = 3;
                }
            }

            # don't bother with the packets, we'll send them out as an event stream later after we store them in the database(?)
            if(my $oid = $self->mango->db('wot-replays')->collection('replays')->save($replay)) {
                $self->db->collection('jobs')->update({ _id => $job->{_id} }, {
                    '$set' => {
                        complete => Mango::BSON::bson_true,
                        status   => 1,
                        replayid => $replay->{_id},
                        banner   => $replay->{site}->{banner},
                        file     => $replay->{file},
                    }
                });
                if(!$job->{reprocess}) {
                    # heatmap only if we're not reprocessing
                    my $bt = $replay->{game}->{bonus_type};
                    my $gid = ($replay->{game}->{type} eq 'ctf')
                        ? 0
                        : ($replay->{game}->{type} eq 'assault') 
                            ? 2
                            : 1;

                }
                $self->job_status($job, {
                    id      =>  'final',
                    text    =>  'Saving replay',
                    type    =>  'spinner',
                    done    =>  Mango::BSON::bson_true,
                });

                # store the heatmap updates
                foreach my $type (keys(%{$o->hm_updates})) {
                    my $data = $o->hm_updates->{$type};
                    my $upd  = {};
                    foreach my $x (keys(%$data)) {
                        foreach my $y (keys(%{$data->{$x}})) {
                            $upd->{sprintf('%d.%d', $x, $y)} += $data->{$x}->{$y};
                        }
                    }
                    $self->db->collection(sprintf('hm_%s', $type))->update({
                        _id     => sprintf('%d_%s', $replay->{game}->{map}, $replay->{game}->{type}),
                    }, { '$inc' => $upd }, { upsert => 1 });
                }

                return $replay;
            } else {
                $self->job_error($job, 'Error saving replay');
                return undef;
            }
        }
    } else {
        $self->job_error($job, $o->error);
        return undef;
    }
}

1;
