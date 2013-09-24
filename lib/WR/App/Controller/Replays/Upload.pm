package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Process;
use DateTime;
use File::Path qw/make_path/;

use FileHandle;
use POSIX();
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

sub stringify_awards {
    my $self = shift;
    my $m_data = shift;
    my $a    = $self->app->wr_res->achievements;
    my $t    = [];

    foreach my $item (@{$m_data->{statistics}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $a->index_to_idstr($item->[0]));
    }
    return $t;
}

sub upload {
    my $self = shift;

    $self->respond(stash => { page => { title => 'Uploads Disabled' } }, template => 'upload/disabled') and return 0 if($self->stash('config')->{features}->{upload} == 0);

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

            $upload->asset->move_to($replay_file);

            $self->model('jobs')->insert({
                type    => 'process',
                file    => $replay_file,
            } => sub {
                my ($c, $e, $oid) = (@_);

                if($e) {
                    $self->render(json => { ok => 1, error => $_ });
                } else {
                    $self->render(json => {
                        ok        => 1,
                        jid       => $oid,
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
