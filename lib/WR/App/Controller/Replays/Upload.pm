package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Process;

use FileHandle;
use POSIX();
use Try::Tiny qw/try catch/;

sub r_error {
    my $self = shift;
    my $message = shift;
    my $file = shift;

    unlink($file);

    $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => $message }, template => 'upload/form');
    return 0;
}

sub nv {
    my $self = shift;
    my $v    = shift;

    $v =~ s/\w+//g;
    $v += 0;
    return $v;
}

sub upload {
    my $self = shift;

    $self->render(template => 'upload/disabled') and return 0 if($self->stash('config')->{features}->{upload} == 0);

    if($self->req->param('a')) {
        if(my $upload = $self->req->upload('replay')) {
            $self->respond(stash => {
                errormessage => 'That is not a .wotreplay file',
                page => { title => 'Upload Replay' }, 
            },
            template => 'upload/form') and return 0 unless($upload->filename =~ /\.wotreplay$/);

            # convert the asset to a file asset
            my $asset = $upload->asset;
            if(ref($asset) eq 'Mojo::File::Memory') {
                my $fileasset = Mojo::Asset::File->new();
                $fileasset->add_chunk($asset->slurp);
                $asset = $fileasset; # heh
            }
            my $pe;
            my $m_data;

            my $filename = $upload->filename;
            $filename =~ s/.*\\//g if($filename =~ /\\/);

            my $replay_file = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $filename);

            $asset->move_to($replay_file);

            try {
                my $p = WR::Process->new(
                    file    => $replay_file,
                    db      => $self->db('wot-replays'),
                    bf_key  => $self->stash('config')->{wot}->{bf_key},
                );
                $m_data = $p->process();
            } catch {
                unlink($replay_file);
                $pe = $_;
            };

            return $self->r_error(sprintf('Error parsing replay: %s', $pe), $replay_file) if($pe);
            return $self->r_error('There is an issue with clan wars replays at the moment that prevents them from being parsed properly, sorry! Can\'t store it...', $replay_file) unless(defined($m_data->{_id}) && !ref($m_data->{_id}));
            return $self->r_error('That replay seems to exist already', $replay_file) if($self->db('wot-replays')->get_collection('replays')->find_one({ _id => $m_data->{_id} }));
            return $self->r_error('That replay seems to be coming from the public test server, we can\'t store those at the moment', $replay_file) if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);
            return $self->r_error(q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player|, $replay_file) if($m_data->{player}->{id} == 0);

            # version check, we'll only accept things one version back

            my $cv = $self->nv($self->stash('config')->{wot}->{version});
            $cv--; # prev version, anything < this is denied

            my $rv = $self->nv($m_data->{version});

            $m_data->{file} = $filename;
            $m_data->{site} = {
                description => $self->req->param('description'),
                uploaded_at => time(),
                uploaded_by => ($self->is_user_authenticated) ? $self->current_user->{_id} : undef,
                visible     => ($self->req->param('hide') == 1) ? false : true,
            };

            $self->db('wot-replays')->get_collection('replays')->save($m_data, { safe => 1 });

            $self->respond(stash => {
                page => { title => 'Upload Replay' }, 
                id => $m_data->{_id}, 
                done => 1,
                published => ($self->req->param('hide') == 1) ? 0 : 1,
            }, template => 'upload/form');

        } else {
            $self->respond(template => 'upload/form', stash => {
                page => { title => 'Upload Replay' },
                errormessage => 'You did not select a file',
            });
        }
    } else {
        $self->respond(template => 'upload/form', stash => { page => { title => 'Upload Replay' } });
    }
}

1;
