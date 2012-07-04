package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Process;

use FileHandle;
use POSIX();
use Try::Tiny qw/try catch/;

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
            my $pe;
            my $m_data;

            my $filename = $upload->filename;
            $filename =~ s/.*\\//g if($filename =~ /\\/);

            $asset->move_to(sprintf('/storage/replays/%s', $filename));

            try {
                my $p = WR::Process->new(
                    file    => sprintf('/storage/replays/%s', $filename),
                    db      => $self->db('wot-replays'),
                    bf_key  => $self->stash('config')->{wot}->{bf_key},
                );
                $m_data = $p->process();
            } catch {
                unlink(sprintf('/storage/replays/%s', $filename));
                $pe = $_;
            };

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => sprintf('Error parsing replay: %s', $pe) }, template => 'upload/form') and return 0 if($pe);

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'There is an issue with clan wars replays at the moment that prevents them from being parsed properly, sorry! Can\'t store it...' }, template => 'upload/form') and return 0 unless(defined($m_data->{_id}) && !ref($m_data->{_id}));
                
            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to exist already' }, template => 'upload/form') and return 0 if($self->db('wot-replays')->get_collection('replays')->find_one({ _id => $m_data->{_id} }));

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to be coming from the public test server, we can\'t store those at the moment' }, template => 'upload/form') and return 0 if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player| }, template => 'upload/form') and return 0 if($m_data->{player}->{id} == 0);

            if(my $yturl = $self->req->param('youtube')) {
                my $tx = $self->get($yturl);

                $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => q|That YouTube video URL isn't quite right...| }, template => 'upload/form') and return 0 unless($tx->success);
            }
            $m_data->{file} = $filename;
            $m_data->{site} = {
                description => $self->req->param('description'),
                uploaded_at => time(),
                uploaded_by => ($self->is_user_authenticated) ? $self->current_user->{_id} : undef,
                visible     => ($self->req->param('hide') == 1) ? false : true,
                youtube     => $self->req->param('youtube'),
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
