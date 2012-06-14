package WR::App::Controller::Replays::Upload;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::Parser;
use FileHandle;
use Mojo::JSON;
use JSON::XS;
use WR::Util;

sub upload {
    my $self = shift;

    if($self->req->param('a')) {
        if(my $upload = $self->req->upload('replay')) {
            $self->respond(stash => {
                errormessage => 'That is not a .wotreplay file',
                page => { title => 'Upload Replay' }, 
            },
            template => 'upload/form') and return 0 unless($upload->filename =~ /\.wotreplay$/);

            my $parser = WR::Parser->new(time_zone => $self->req->param('timezone'));
            $parser->parse($upload->asset->slurp);
            my $m_data = $parser->result_for_mongo;

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to exist already' }, template => 'upload/form') and return 0 if($self->db('wot-replays')->get_collection('replays')->find_one({ _id => $m_data->{_id} }));

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => 'That replay seems to be coming from the public test server, we can\'t store those at the moment' }, template => 'upload/form') and return 0 if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);

            $self->respond(stash => { page => { title => 'Upload Replay' }, errormessage => q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player| }, template => 'upload/form') and return 0 if($m_data->{player}->{id} == 0);

            my $asset = $upload->asset;
            if(ref($asset) eq 'Mojo::File::Memory') {
                my $fileasset = Mojo::Asset::File->new();
                $fileasset->add_chunk($asset->slurp);
                $asset = $fileasset; # heh
            }
            my $gfs = $self->db('wot-replays')->get_gridfs();
            $gfs->remove({ replay_id => $m_data->{_id} });

            my $tf = sprintf('/tmp/%s.wotreplay', $m_data->{_id});
            $asset->move_to($tf);
            if(my $handle = FileHandle->new($tf, 'r')) {
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

                # find out whether this match awards mastery or not
                $m_data->{player}->{statistics}->{mastery} = WR::Util::award_mastery($self, $m_data->{player}->{name}, $m_data->{player}->{vehicle}->{full}, $m_data->{player}->{statistics}->{mastery}) if($m_data->{player}->{statistics} && $m_data->{player}->{statistics}->{mastery} > 0);

                # get the player server
                $m_data->{player}->{server} = WR::Util::server_finder($self, $m_data->{player}->{id}, $m_data->{player}->{name});

                # see if we need to process team kills
                if($m_data->{complete}) {
                    if(scalar(@{$m_data->{player}->{statistics}->{teamkill}->{log}}) > 0) {
                        foreach my $entry (@{$m_data->{player}->{statistics}->{teamkill}->{log}}) {
                            if(my $name = WR::Util::user_finder($self, $entry->{targetID}, $m_data->{player}->{server})) {
                                my $vid = $m_data->{vehicles_hash_name}->{$name}->{id};
                                $m_data->{player}->{statistics}->{teamkill}->{hash}->{$vid} = $entry;
                            }
                        }
                    }
                }

                $self->db('wot-replays')->get_collection('replays')->save($m_data);

                $self->respond(stash => {
                    page => { title => 'Upload Replay' }, 
                    is_complete => $parser->is_complete, 
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
