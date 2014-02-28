package WR::Daemon::Process::Master;
use FindBin;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Log;
use Mango;
use Mango::BSON;
use WR::Thunderpush::Client;
use Data::Dumper;
use POSIX ":sys_wait_h";

has 'config'            => sub { {} };
has 'log'               => sub {
    my $self = shift;
    my $log;

    if(my $lf = $self->config->{processd}->{master}->{logfile} && !$self->log_stdout) {
        $lf = sprintf('%s/../%s', $FindBin::Bin, $self->config->{processd}->{logfile}) if($lf !~ /^\//);
        $log = Mojo::Log->new(path => $lf, level => $self->config->{processd}->{master}->{loglevel} || 'warn');
    } else {
        $log = Mojo::Log->new(level => 'debug');
    }
    return $log;
};

has 'log_stdout'        => undef;
has 'pause_work'        => 0;
has 'cfile'             => sub { return sprintf('%s/%s', $FindBin::Bin, shift->config->{processd}->{worker}->{configfile}) }; # a bit over the top maybe but ...

has 'mango'             => sub { 
    my $self = shift;
    return Mango->new($self->config->{mongodb}->{host});
};

has 'db'                => sub {
    my $self = shift;
    return $self->mango->db($self->config->{mongodb}->{database});
};
has 'workers'           =>  2;
has 'children'          =>  sub { {} };
has 'child_count'       =>  0;
has 'last_hb_received'  =>  0;
has 'timers'            =>  sub { {} };
has 'push'              =>  undef;
has 'work_list'         =>  sub { [] };
has 'pending'           =>  sub { {} };

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub error   { shift->_log('error', @_) }

sub push_work {
    my $self = shift;
    my $id   = shift;

    push(@{$self->work_list}, $id);
}

sub get_work {
    my $self = shift;

    return shift(@{$self->work_list});
}

sub has_work {
    my $self = shift;

    return (scalar(@{$self->work_list}) > 0) ? 1 : 0;
}

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join('', '[Daemon::Process::Master ', $$, ']: ', @_);

    $self->log->$l($m);
}

sub on_sigTERM {
    my $self = shift;

    return sub {
        $self->info('Received SIGTERM, terminating all children');
        Mojo::IOLoop->remove($self->timers->{'work'});
        $self->push->finish;
    };
}

sub on_sigKILL {
    my $self = shift;

    return sub {
        $self->info('Received SIGKILL, terminating all children');
        Mojo::IOLoop->remove($self->timers->{'work'});
        $self->push->finish;
    };
}

sub on_sigUSR1 {
    my $self = shift;

    return sub {
        my $w = $self->workers;
        $self->info('Received SIGUSR1, adding 1 to worker count: was: ', $w, ' now ', $w+1);
        $self->workers($w + 1);
        $SIG{USR1} = $self->on_sigUSR1;
    };
}

sub on_sigUSR2 {
    my $self = shift;

    return sub {
        my $w = $self->workers;
        if($w > 1) {
            $self->info('Received SIGUSR2, removing 1 to worker count: was: ', $w, ' now ', $w-1);
            $self->workers($w-1);
        } else {
            $self->info('Received SIGUSR2, but worker count already 1');
        }
        $SIG{USR2} = $self->on_sigUSR2;
    };
}

sub terminate_all_children_and_wait {
    my $self = shift;
    my $sig  = shift || 15;

    if($self->child_count > 0) {
        kill($sig, (keys(%{$self->children})));
    } else {
        $self->emit('no_more_children');
    }
}

sub remove_child {
    my $self = shift;
    my $pid  = shift;

    $self->debug('removing worker ', $pid);
    delete($self->children->{$pid});
    delete($self->pending->{$pid});
    $self->child_count($self->child_count - 1);
    $self->debug('child count: ', $self->child_count, ' children says: ', scalar(keys(%{$self->children})), ' pending: ', scalar(keys(%{$self->pending})));
    $self->emit('no_more_children') if($self->child_count == 0);
}

sub is_pending {
    my $self = shift;
    my $id   = shift;

    foreach my $pid (keys(%{$self->pending})) {
        return 1 if($self->pending->{$pid} eq $id);
    }
    return 0;
}

sub on_sigCHLD {
    my $self = shift;

    return sub {
        while ((my $child = waitpid(-1, WNOHANG)) > 0) {
            $self->debug('Received SIGCHLD for ', $child);
            $self->remove_child($child);
        }
        $SIG{CHLD} = $self->on_sigCHLD;
    };
}

sub fork_worker {
    my $self   = shift;
    my $jobid  = shift;
    my $worker = sprintf('%s/processd.worker', $FindBin::Bin);

    my @args = ('--config', $self->cfile, '--job-id', $jobid);
    push(@args, '--log-stdout') if($self->log_stdout);

    $self->debug('about to fork worker using: [', $worker, ' ', join(' ', @args), '] for jobid: ', $jobid, ' is_pending: ', $self->is_pending($jobid));

    my $pid = fork();
    return undef unless(defined($pid));

    if($pid == 0) {
        # child
        exec($worker, @args);
        die '[worker exec failed]: ', $!, "\n";
    } else {
        $self->child_count($self->child_count + 1);
        $self->children->{$pid}++;
        $self->debug('forked a worker with pid ', $pid, ' for jobid ', $jobid);
        $self->pending->{$pid} = $jobid;
        return 1;
    }
}

sub reload_work_list {
    my $self   = shift;

    $self->pause_work(1);
    $self->db->collection('jobs')->find({ ready => Mango::BSON::bson_true, complete => Mango::BSON::bson_false })->sort({ priority => 1, ctime => 1 })->all(sub {
        my ($coll, $err, $docs) = (@_);

        if(defined($err) || !defined($docs)) {
            $self->error('job queue reload failed: ', $err);
        } else {
            my $work   = [];
            my $unlock = [];

            foreach my $job (@$docs) {
                if($job->{locked}) {
                    unless(kill(0, $job->{locked_by})) {
                        $self->debug('received locked job, locking pid is no longer running; unlocking job');
                        push(@$unlock, $job->{_id});
                    }
                } else {
                    push(@$work, $job->{_id} . '') unless($self->is_pending($job->{_id} . ''));
                }
            }

            $self->debug('received new job list, ', scalar(@$work), ' work list entries, ', scalar(@$unlock), ' unlock entries');

            if(scalar(@$unlock) > 0) {
                my $delay = Mojo::IOLoop->delay(sub {
                    my ($d, @res) = (@_);
                    $self->debug('jobs unlocked');
                    $self->work_list([@$work,@res]);
                    $self->pause_work(0);
                });
                foreach my $id (@$unlock) {
                    my $end = $delay->begin(0);
                    $self->db->collection('jobs')->update({ _id => $id }, { '$set' => { 'locked' => Mango::BSON::bson_false } } => sub { 
                        $end->($id) 
                    });
                }
            } else {
                $self->work_list($work);
                $self->pause_work(0);
            }
        }
    });
}

sub start {
    my $self = shift;

    $self->info('processd.master starting');

    $SIG{CHLD} = $self->on_sigCHLD;
    $SIG{TERM} = $self->on_sigTERM;
    $SIG{KILL} = $self->on_sigKILL;
    $SIG{USR1} = $self->on_sigUSR1;
    $SIG{USR2} = $self->on_sigUSR2;

    $self->push(
        WR::Thunderpush::Client->new(
            host        => 'push.wotreplays.org',
            key         => $self->config->{thunderpush}->{key}, 
            secret      => $self->config->{thunderpush}->{secret},
            user        => 'processd.master',
            channels    => ['site'],
        )
    );

    $self->push->on(heartbeat => sub {
        $self->last_hb_received(time());
        $self->debug('received heartbeat');
    });

    $self->push->on('connect' => sub {
        my ($p, $s) = (@_);
        if($s->{status} != 1) {
            Mojo::IOLoop->timer(5 => sub {
                $self->push->connect;
            });
            $self->debug('received connect, status not ok, reconnecting in 5: ', Dumper($s));
        } else {
            $self->debug('received connect, status 1');
        }
    });

    $self->push->on('open' => sub {
        $self->timers->{'hb_check'} = Mojo::IOLoop->recurring(60 => sub {
            $self->debug('hb_check, last_hb_received is: ', $self->last_hb_received);
            $self->push->finish if($self->last_hb_received + 120 < time());
        });
        $self->last_hb_received(time());
        $self->debug('received open');
    });

    $self->push->on(finished => sub {
        my ($p, $s) = (@_);

        $self->debug('received finish');
        Mojo::IOLoop->remove($self->timers->{'hb_check'});
        Mojo::IOLoop->remove($self->timers->{'work'});

        # exit if we have no more children left
        if($self->child_count == 0) {
            $self->debug('no children left, exiting immediately');
            exit(0);
        } else {
            $self->on('no_more_children' => sub {
                $self->debug('no children left, exiting');
                exit(0);
            });
            $self->debug('still have active children, waiting...');
            $self->terminate_all_children_and_wait(15);
        }
    });

    $self->push->on(message => sub {
        my ($p, $m) = (@_);

        if(defined($m->{evt}) && $m->{evt} eq 'replay.upload') {
            $self->debug('new upload on site, reload work list');
            $self->reload_work_list;
        }
    });

    $self->reload_work_list; 
    $self->timers->{'work'} = Mojo::IOLoop->recurring(1 => sub {
        return unless($self->has_work);
        return if($self->pause_work);

        $self->pause_work(1);
        # see if we can do this one..
        while($self->child_count < $self->workers && $self->has_work) {
            $self->fork_worker($self->get_work);
        }
        $self->pause_work(0);
    });
    $self->debug('about to connect');
    $self->push->connect;
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

1;
