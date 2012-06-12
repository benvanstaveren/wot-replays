package WR::Controller::Wru;
use Mojo::Base 'WR::Controller';
use WR::Parser;
use FileHandle;
use boolean;
use Mojo::JSON;
use JSON::XS;
use WR::Util;

sub index {
    shift->respond(template => 'wru', stash => { page => { title => 'World of Tanks Replay Uploader' } });
}

sub get_token {
    my $self = shift;
    my $u    = $self->req->param('u');
    my $p    = $self->req->param('p');
    my $tz   = $self->req->param('tz');

    unless($u && $p) {
        $self->render(json => { ok => 0, error => 'No username or password supplied', term => 0 });
    } else {
        if(my $user = $self->db('wot-replays')->get_collection('accounts')->find_one({ email => $u })) {
            my $token = MongoDB::OID->new()->to_string(); # hehm. funny. 
            my $pass = $user->{password};
            my $salt = substr($pass, 0, 2);
            if(crypt($p, $salt) eq $pass) {
                $self->db('wot-replays')->get_collection('accounts')->update({ _id => $user->{_id } }, { '$set' => { token => $token } });
                $self->render(json => { ok => 1, token => $token, term => 0 });
            } else {
                $self->render(json => { ok => 0, error => 'Invalid password...', term => 0 });
            }
        } else {
            $self->render(json => { ok => 0, error => 'That account does not exist, do you have one? If not, go register one...', term => 0 });
        }
    } 
}

sub upload {
    my $self = shift;
    my $token = $self->req->param('wru_token');
    my $timezone = $self->req->param('timezone');

    my $user = $self->db('wot-replays')->get_collection('accounts')->find_one({ token => $token });
    $self->render(json => { ok => 0, error => 'Invalid token' }) and return 0 unless(defined($user));

    if(my $upload = $self->req->upload('replay')) {
        my $parser = WR::Parser->new(time_zone => $timezone);
        $parser->parse($upload->asset->slurp);
        my $m_data = $parser->result_for_mongo;

        $self->render(json => { ok => 0, duplicate => 1 }) and return 0 if($self->db('wot-replays')->get_collection('replays')->find_one({ _id => $m_data->{_id} }));
        $self->render(json => { ok => 0, duplicate => 1 }) and return 0 if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);
        $self->render(json => { ok => 0, duplicate => 1 }) and return 0 if($m_data->{player}->{id} == 0);


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
                description => undef,
                uploaded_at => $f_id->get_time,
                uploaded_by => bless({ value => $user->{_id} }, 'MongoDB::OID'),
                visible     => false,
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
            $self->render(json => { ok => 1 });
        } else {
            $self->render(json => { ok => 0, error => 'Could not store replay file' });
        }
    } else {
        $self->render(json => { ok => 0, error => 'Umm, upload missing?' });
    }
}

1;
