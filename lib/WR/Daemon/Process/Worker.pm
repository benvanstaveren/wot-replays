package WR::Daemon::Process::Worker;
use Mojo::Base 'Mojo::EventEmitter';
use FindBin;
use Mojo::Log;
use Mango;
use Mango::BSON;
use Try::Tiny qw/try catch/;
use WR::Thunderpush::Client; # because yes... 
use WR::Process::Job;

use WR::Process::Chatreader;
use WR::Process::Full;

has 'config'            => sub { {} };
has 'log'               => sub {
    my $self = shift;
    my $log;

    if(my $lf = $self->config->{processd}->{worker}->{logfile} && !$self->log_stdout) {
        $lf = sprintf('%s/../%s', $FindBin::Bin, $self->config->{processd}->{worker}->{logfile}) if($lf !~ /^\//);
        $log = Mojo::Log->new(path => $lf, level => $self->config->{processd}->{worker}->{loglevel} || 'warn');
    } else {
        $log = Mojo::Log->new(level => 'debug');
    }
    return $log;
};

has 'job_id'            => undef;
has 'log_stdout'        => undef;
has 'mango'             => sub { 
    my $self = shift;
    return Mango->new($self->config->{mongodb}->{host});
};
has 'db'                => sub {
    my $self = shift;
    return $self->mango->db($self->config->{mongodb}->{database});
};

sub debug   { shift->_log('debug', @_) }
sub info    { shift->_log('info', @_) }
sub error   { shift->_log('error', @_) }
sub fatal   { shift->_log('fatal', @_); exit(0) }

sub _log {
    my $self = shift;
    my $l    = shift;
    my $m    = join('', '[Daemon::Process::Worker ', $$, ']: ', @_);

    $self->log->$l($m);
}

sub start {
    my $self = shift;

    $self->info('processd.worker starting for ', $self->job_id);

    # load the job 
    if(my $job = WR::Process::Job->new(_id => $self->job_id, _coll => $self->db->collection('jobs'))) {
        $job->load(sub {
            my ($j, $e) = (@_);

            if(defined($e)) {
                $self->fatal('Could not load job: ', $e);
            } else {
                $self->init($job);
            }
        });
    } else {
        $self->error('Could not instantiate new WR::Process::Job');
        exit(0);
    }

    $self->debug('starting IOLoop');
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub init {
    my $self = shift;
    my $job  = shift;

    # see if we can lock it
    if($job->locked) {
        $self->fatal('Job is already locked');
    } else {
        $job->lock(sub {
            my ($j, $e) = (@_);
            $self->fatal('Could not lock job: ', $e) if(defined($e));

            my $type = $job->type || 'full';
            my $module = sprintf('WR::Process::%s', ucfirst($type));
            $self->debug('processing module: ', $module);
            try {
                # the worker module(s) do their entire own thing, all we need is to wait for a callback 
                # that indicates we're done
                $self->debug('instantiating ', $module);
                my $m = $module->new(
                    config      =>  $self->config,
                    job         =>  $job->start,
                    log         =>  $self->log,
                );
                $self->debug($module, ' instantiated: ', $m);
                $m->process(sub {
                    $self->debug('process finished, exiting');
                    exit(0);
                });
            } catch {
                my $e = $_;
                $self->debug('error: ', $e);
                $job->set_error($e, sub {
                    $self->error('Could not process job of ', $type, ' using ', $module, ': ', $e);
                    $job->unlink;
                    exit(0);
                });
            };
        });
    }
}

1;
