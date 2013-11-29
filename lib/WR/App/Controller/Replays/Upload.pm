package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use File::Path qw/make_path/;
use Try::Tiny qw/try catch/;
use Digest::SHA1;

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

sub upload {
    my $self = shift;

    if($self->req->param('a')) {
        $self->render_later;
        if(my $upload = $self->req->upload('replay')) {
            return $self->r_error(q|That does not look like a replay|) unless($upload->filename =~ /\.wotreplay$/);
            my $filename = $upload->filename;
            $filename =~ s/.*\\//g if($filename =~ /\\/);

            my $hashbucket_size = length($filename);
            $hashbucket_size = 7 if($hashbucket_size > 7);
            my $replay_filename = $filename;
            my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $self->hashbucket($filename, $hashbucket_size));
            my $replay_file = sprintf('%s/%s', $replay_path, $filename);
            my $replay_file_base = sprintf('%s/%s', $self->hashbucket($filename, $hashbucket_size), $filename);

            make_path($replay_path);

            #$self->render(json => { ok => 0, error => 'You might want to rename the replay file first, we already seem to have one with the same name...' }) and return if(-e $replay_file);

            my $sha = Digest::SHA1->new();
            $sha->add($upload->asset->slurp);
            $sha->add($replay_filename);       
            my $digest = $sha->hexdigest;

            # set this up as the job id
            $self->model('wot-replays.jobs')->save({
                _id         => $digest,
                ready       => Mango::BSON::bson_false,
                complete    => Mango::BSON::bson_false,
                status      => 0,
                error       => undef,
                replayid    => undef,
                ctime       => Mango::BSON::bson_time,
                status_text => [ ],
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
                            },
                            ready => Mango::BSON::bson_true,
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
        } else {
            $self->render(json => { ok => 0, error => 'You did not select a file...' });
        }
    } else {
        $self->respond(template => 'upload/form', stash => { page => { title => 'Upload Replay' } });
    }
}

sub process_replay {
    my $self = shift;
    my $jid  = $self->stash('jobid');

    $self->render_later;
    $self->model('wot-replays.jobs')->find_one({ _id => $jid } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($doc)) {
            $self->render(json => $doc);
        } else {
            $self->render(json => { status => -1, error => 'No such job ID exists' });
        }
    });
}

1;
