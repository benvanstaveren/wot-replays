package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use WR::Process;
use Mango::BSON;
use File::Path qw/make_path/;
use Try::Tiny qw/try catch/;
use Data::Dumper;

sub r_error {
    my $self = shift;
    my $message = shift;
    my $file = shift;

    unlink($file);
    $self->render(json => { ok => 0, error => $message });
    return 0;
}

sub r_error_redirect {
    my $self = shift;
    my $to = shift;
    my $file = shift;

    unlink($file);
    $self->render(json => { ok => 0, redirect => $to });
    return 0;
}

sub nv {
    my $self = shift;
    my $v    = shift;

    $v =~ s/\w+//g;
    $v += 0;
    return $v;
}

sub process_replay {
    my $self = shift;
    my $k    = $self->req->param('jid');

    Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

    $self->render_later;

    # where to get the app's ioloop from? 

    if(my $job = $self->model('wot-replays.jobs')->find_one({ _id => $k })) {
        my $file = $job->{data}->{file};
        my $replay;
        my $process = try {
            return WR::Process->new(
                bf_key      => $self->stash('config')->{wot}->{bf_key},
                file        => $file,
                mango       => $self->app->mango,
                banner_path => $self->stash('config')->{paths}->{banners},
   		        ua	        => $self->ua,
            );
        } catch {
            unlink($file);
            $self->render(json => { ok => 0, error => 'Could not parse replay: ' . $_ });
        };

        $process->process(sub {
            my $replay = shift;
            if(defined($replay)) {
                if(!defined($replay->{game}->{version_numeric}) || (defined($replay->{game}->{version_numeric}) && $replay->{game}->{version_numeric} < $self->stash('config')->{wot}->{min_version})) {
                    unlink($file);
                    $self->render(json => { ok => 0, error => 'That replay is from an older version of World of Tanks which we cannot process' }) and return;
                }

                $replay->{digest} = $job->{_id};
                $replay->{site}->{visible} = Mango::BSON::bson_false if($job->{data}->{visible} < 1);
                $replay->{site}->{description} = (defined($job->{data}->{desc}) && length($job->{data}->{desc}) > 0) ? $job->{data}->{desc} : undef;
                $replay->{file} = $job->{data}->{file_base}; # kind of essential to have that, yeah...

                # don't bother with the packets, we'll send them out as an event stream later after we store them in the database(?)
                $self->model('wot-replays.replays')->insert($replay => sub {
                    my ($coll, $err, $oid) = (@_);
                    if($err) {
                        $self->render(json => { ok => 0, error => $err });
                    } else {
                        $self->render(json => { ok => 1, result => { oid => $replay->{_id} . '', banner => $replay->{site}->{banner}, base => $job->{data}->{file_base} }});
                    }
                });
            } else {
                $self->render(json => { ok => 0, error => $_ });
            }
        });
    } else {
        $self->render(json => { ok => 0, error => 'No job key supplied' });
    }
}

sub upload {
    my $self = shift;

    if($self->req->param('a')) {
        $self->render_later;
        if(my $upload = $self->req->upload('replay')) {
            return $self->r_error(q|That does not look like a replay|) unless($upload->filename =~ /\.wotreplay$/);
            my $filename = $upload->filename;
            $filename =~ s/.*\\//g if($filename =~ /\\/);

            my $hashbucket_size = length($filename);
            $hashbucket_size = 7 if($hashbucket_size >= 7);


            my $replay_filename = $filename;
            my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $self->hashbucket($filename, $hashbucket_size));
            my $replay_file = sprintf('%s/%s', $replay_path, $filename);
            my $replay_file_base = sprintf('%s/%s', $self->hashbucket($filename, $hashbucket_size), $filename);

            make_path($replay_path);

            $self->render(json => { ok => 0, error => 'You might want to rename the replay file first, we already seem to have one with the same name...' }) and return if(-e $replay_file);

            my $sha = Digest::SHA1->new();
            $sha->add($upload->asset->slurp);
            my $digest = $sha->hexdigest;

            # set this up as the job id
            $self->model('wot-replays.jobs')->find_one({ _id=> $digest } => sub {
                my ($coll, $err, $doc) = (@_);

                if(defined($doc) && !defined($err)) {
                    $self->app->log->info('Existing replayfor digest: ', $digest, ' and doc dump: ', Dumper($doc));
                    $self->render(json => { ok => 0, error => 'It appears that replay has been uploaded already...' }) and return;
                } else {
                    $self->model('wot-replays.jobs')->save({
                        _id         => $digest,
                        ctime       => Mango::BSON::bson_time,
                        data        => { }
                    } => sub {
                        my ($coll, $err, $oid) = (@_);

                        if(defined($oid)) {
                            $upload->asset->move_to($replay_file);

                            my $hide = (defined($self->req->param('hide'))) ? $self->req->param('hide') : 0;
                            my $desc = $self->req->param('description');

                            $self->model('wot-replays.jobs')->update({ _id => $digest }, { 
                                '$set' => {
                                    'data'  => {
                                        file => $replay_file,
                                        file_base => $replay_file_base,
                                        desc => (defined($desc)) ? $desc : '',
                                        visible => ($hide == 1) ? 0 : 1
                                    }
                                }
                            } => sub {
                                my ($coll, $err, $oid) = (@_);

                                if($err) {
                                    $self->render(json => { ok => 0, error => $_ });
                                } else {
                                    $self->render(json => { ok => 1, jid => $digest });
                                }
                            });
                        } else {    
                            $self->render(json => { ok => 0, error => 'Could not store process job' });
                        }
                    });
                }
            });
        } else {
            $self->render(json => {
                ok => 0,
                error => 'You did not select a file',
            });
        }
    } else {
        $self->respond(template => 'upload/form', stash => { page => { title => 'Upload Replay' } });
    }
}

1;
