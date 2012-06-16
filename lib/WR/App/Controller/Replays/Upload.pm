package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Process;

use FileHandle;
use Mojo::JSON;
use JSON::XS;

sub upload {
    my $self = shift;

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
            my $gfs = $self->db('wot-replays')->get_gridfs();

            my $pe;

            my $m_data = try {
                my $p = WR::Process->new(
                    file    => $asset->path,
                    db      => $self->db('wot-replays'),
                    bf_key  => $self->stash('configuration')->{wot}->{bf_key},
                );
                return $p->process();
            } catch {
                $pe = $_;
            };

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'Error parsing replay' }, template => 'upload/form') if($pe);
                
            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to exist already' }, template => 'upload/form') and return 0 if($self->db('wot-replays')->get_collection('replays')->find_one({ _id => $m_data->{_id} }));

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to be coming from the public test server, we can\'t store those at the moment' }, template => 'upload/form') and return 0 if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player| }, template => 'upload/form') and return 0 if($m_data->{player}->{id} == 0);

            $gfs->remove({ replay_id => $m_data->{_id} });

            if(my $handle = FileHandle->new($asset->path, 'r')) {
                my $f_id = $gfs->insert($handle, {
                    filename    => $upload->filename,
                    replay_id   => $m_data->{_id},
                }, { safe => 1});
                unlink($tf);
                $m_data->{file} = $f_id;
                $m_data->{site} = {
                    description => $self->req->param('description'),
                    uploaded_at => $f_id->get_time,
                    uploaded_by => ($self->is_user_authenticated) ? $self->current_user->{_id} : undef,
                    visible     => ($self->req->param('hide') == 1) ? false : true,
                };
                $self->db('wot-replays')->get_collection('replays')->save($m_data, { safe =>  });

                $self->respond(stash => {
                    page => { title => 'Upload Replay' }, 
                    id => $m_data->{_id}, 
                    done => 1,
                    published => ($self->req->param('hide') == 1) ? 0 : 1,
                }, template => 'upload/form');
            } else {
                $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'Error saving to gridfs', }, template => 'upload/form');
            }
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
