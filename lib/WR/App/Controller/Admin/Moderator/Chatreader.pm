package WR::App::Controller::Admin::Moderator::Chatreader;
use Mojo::Base 'WR::App::Controller';
use File::Path qw/make_path/;

sub index {
    my $self = shift;

    $self->respond(template => 'admin/moderator/chatreader/index', stash => {
        page => { title => 'Moderator Tools - Chat Reader' },
    });
}

sub r_error {
    my $self = shift;
    my $msg  = shift;

    $self->render(json => { ok => 0, error => $msg });
    return undef;
}

sub process {
    my $self = shift;

    # we store these in the temp folder
    my $directory = $self->app->home->rel_dir('tmp/chatreader');
    make_path($directory) unless(-e $directory);

    $self->render_later;

    if(my $upload = $self->req->upload('replay')) {
        return $self->r_error(q|That does not look like a replay|) unless($upload->filename =~ /\.wotreplay$/);

        # generate a random filename
        my $alpha    = ['A'..'Z','a'..'z'];
        my $filename = '';
        while(length($filename) < 32) {
            $filename .= $alpha->[int(rand(scalar(@$alpha)))];
        }
        my $channel = sprintf('cr_%s', $filename);
        my $replay_file = sprintf('%s/%s.wotreplay', $directory, $filename);

        $upload->asset->move_to($replay_file);
        $self->model('wot-replays.jobs')->save({
            _id         => sprintf('%s-%d', $channel, Mango::BSON::bson_time),
            type        => 'chatreader',
            ready       => Mango::BSON::bson_true,
            complete    => Mango::BSON::bson_false,
            status      => 0,
            error       => undef,
            ctime       => Mango::BSON::bson_time,
            status_text => [ ],
            channel     => $channel,
            data        => { 
                file => $replay_file,
            },
            priority    => 10,
        } => sub {
            my ($coll, $err, $oid) = (@_);
            if(defined($oid)) {
                $self->render(json => { ok => 1, channel => $channel });
            } else {
                $self->render(json => { ok => 0, error => 'Could not save process job' });
            }
        });
    } else {
        $self->render(json => { ok => 0, error => 'You did not select a replay file' });
    }
}

1;
