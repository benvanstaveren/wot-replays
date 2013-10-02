package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use WR::Process;
use Mango::BSON;
use File::Path qw/make_path/;
use Try::Tiny qw/try catch/;

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
    my $oid  = Mango::BSON::bson_oid($k);

    # no render_later because the process module doesn't use non-blocking, 
    # so that may cause errors if you use blocking operations inside a non-blocking
    # operation

    Mojo::IOLoop->stream($self->tx->connection)->timeout(300);

    $self->render_later;

    $self->model('wot-replays.jobs')->find_one({ _id => $oid } => sub {
        my ($c, $e, $job) = (@_);

        if(!defined($job) || (defined($e))) {
            $self->render(json => { ok => 0, error => 'No job key supplied, or error occurred' });
            return;
        }

        my $file = $job->{data}->{file};
        my $process = WR::Process->new(
            bf_key      => $self->stash('config')->{wot}->{bf_key},
            file        => $file,
            mango       => $self->app->mango,
            banner_path => $self->stash('config')->{paths}->{banners},
        );
        $process->process(sub {
            my ($process, $replay) = (@_);
            if(defined($replay)) {
                $self->model('wot-replays.replays')->find_one({ digest => $replay->{digest} } => sub {
                    my ($c, $e, $d) = (@_);

                    if(defined($d)) {
                        unlink($file); # and yes, it's possible to rename your uploads and clobber an existing file this way
                        $self->render(json => { ok => 0, error => 'That replay has already been uploaded' }) and return;
                    }

                    if(!defined($replay->{game}->{version_numeric}) || (defined($replay->{game}->{version_numeric}) && $replay->{game}->{version_numeric} < $self->stash('config')->{wot}->{min_version})) {
                        unlink($file);
                        $self->render(json => { ok => 0, error => 'That replay is from an older version of World of Tanks which we cannot process' }) and return;
                    }

                    $replay->{site}->{visible} = Mango::BSON::bson_false if($job->{data}->{visible} < 1);
                    $replay->{site}->{description} = (defined($job->{data}->{desc}) && length($job->{data}->{desc}) > 0) ? $job->{data}->{desc} : undef;
                    $replay->{file} = $job->{data}->{file_base}; # kind of essential to have that, yeah...

                    my $packets = delete($replay->{__packets__});
                    my $path = sprintf('%s/%s', $self->stash('config')->{paths}->{packets}, $self->hashbucket($replay->{_id} . ''));
                    make_path($path) unless(-e $path);
                    my $packet_base = sprintf('%s/%s.json', $self->hashbucket($replay->{_id} . ''), $replay->{_id} . '');
                    my $packet_file = sprintf('%s/%s.json', $path, $replay->{_id} . '');
                    $replay->{site}->{packets} = $packet_base;
                    try {
                        if(my $fh = IO::File->new('>' . $packet_file)) {
                            $fh->print(Mojo::JSON->new->encode($packets));
                            $fh->close;
                        } else {
                            delete($replay->{site}->{packets});
                        }
                    } catch {
                    }; # no-op

                    $self->model('wot-replays.replays')->insert($replay => sub {
                        $self->render(json => { ok => 1, result => { oid => $replay->{_id} . '', banner => $replay->{site}->{banner}, base => $job->{data}->{file_base} }});
                    });
                });
            } else {
                unlink($file); 
                $self->render(json => { ok => 0, error => $process->error });
            }
        });
    });
}

sub upload {
    my $self = shift;

    if($self->req->param('a')) {
        if(my $upload = $self->req->upload('replay')) {
            return $self->r_error(q|That does not look like a replay|) unless($upload->filename =~ /\.wotreplay$/);
            my $filename = $upload->filename;
            $filename =~ s/.*\\//g if($filename =~ /\\/);

            my $replay_filename = $filename;
            my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $self->hashbucket($filename));
            my $replay_file = sprintf('%s/%s', $replay_path, $filename);
            my $replay_file_base = sprintf('%s/%s', $self->hashbucket($filename), $filename);

            make_path($replay_path);

            if(-e $replay_file) {
                $self->render(json => { ok => 0, error => 'You might want to rename the replay file first, we already seem to have one with the same name...' }) and return;
            }

            $upload->asset->move_to($replay_file);

            $self->render_later;

            my $hide = (defined($self->req->param('hide'))) ? $self->req->param('hide') : 0;
            my $desc = $self->req->param('description');

            my $data = {
                file => $replay_file,
                file_base => $replay_file_base,
                desc => (defined($desc)) ? $desc : '',
                visible => ($hide == 1) ? 0 : 1,
                };

            # store a quick key and return for processing 
            $self->model('wot-replays.jobs')->insert({ type => 'process', data => $data  } => sub {
                my ($c, $e, $oid) = (@_);
                if($e) {
                    $self->render(json => { ok => 0, error => $_ });
                } else {
                    $self->render(json => { ok => 1, jid => $oid });
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
