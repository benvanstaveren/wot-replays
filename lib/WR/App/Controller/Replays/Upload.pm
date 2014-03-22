package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;
use File::Path qw/make_path/;
use Try::Tiny qw/try catch/;
use Digest::SHA qw/sha256_hex/;

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

sub rfrag {
    my $self = shift;
    my $a    = [ 'A'..'Z', 'a'..'z', 0..9 ];
    my $s    = '';

    while(length($s) < 7) {
        $s .= $a->[int(rand(scalar(@$a)))];
    }
    return $s;
}

sub upload {
    my $self = shift;
    my $type = $self->stash('upload_type');

    $self->redirect_to('/login') and return unless($self->is_user_authenticated);

    if(!defined($type)) {
        # redirect user to their preferred upload page, for now, single
        $self->respond(template => 'upload/single', stash => { page => { title => 'Upload Replay' } });
    } else {
        if($type !~ /^(single|batch)$/) {
            $self->respond(template => 'upload/single', stash => { page => { title => 'Upload Replay' } });
        } else {
            $self->respond(template => sprintf('upload/%s', lc($type)), stash => { page => { title => 'Upload Replay' } });
        }
    }
}

sub process_upload {
    my $self = shift;

    $self->render_later;
    if(my $upload = $self->req->upload('replay')) {
        return $self->r_error(q|That does not look like a replay|) unless($upload->filename =~ /\.wotreplay$/);

        # generate a random fragment 
        my $filename = $upload->filename;
        $filename =~ s/.*\\//g if($filename =~ /\\/);
        $filename =~ s/[#\*\(\)\[\]\{\}\?\\\,\;\/]/_/g; 
        $filename = sprintf('%s-%s', $self->rfrag, $filename);

        my $hashbucket_size = length($filename);
        $hashbucket_size = 7 if($hashbucket_size > 7);


        my $replay_filename = $filename;
        my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $self->hashbucket($filename, $hashbucket_size));
        my $replay_file = sprintf('%s/%s', $replay_path, $filename);
        my $replay_file_base = sprintf('%s/%s', $self->hashbucket($filename, $hashbucket_size), $filename);

        make_path($replay_path);

        my $digest = sha256_hex($upload->asset->slurp);
        my $prio   = 50;

        # set this up as the job id
        $self->model('wot-replays.jobs')->save({
            _id         => $digest,
            uploader    => $self->current_user, 
            ready       => Mango::BSON::bson_false,
            complete    => Mango::BSON::bson_false,
            status      => 0,
            error       => undef,
            replayid    => undef,
            ctime       => Mango::BSON::bson_time,
            status_text => [ ],
            data        => { },
            priority    => $prio,
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
                            visible => ($hide > 0) ? 0 : 1,
                            privacy => $hide,
                        },
                        ready => Mango::BSON::bson_true,
                    }
                } => sub {
                    my ($coll, $err, $oid) = (@_);

                    if($err) {
                        $self->render(json => { ok => 0, error => $_, oid => $oid });
                    } else {
                        $self->app->thunderpush->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.upload', data => { job_id => $digest} }) => sub {
                            my ($p, $r) = (@_);
                            $self->render(json => { ok => 1, jid => $digest });
                        });
                    }
                });
            } else {    
                $self->render(json => { ok => 0, error => 'Could not store process job' });
            }
        });
    } else {
        $self->render(json => { ok => 0, error => 'You did not select a file...' });
    }
}

1;
