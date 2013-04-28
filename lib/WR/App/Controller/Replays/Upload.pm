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

            my $dt = DateTime->now();
            my $replay_filename = sprintf('%s/%s', $dt->strftime('%Y/%m/%d'), $filename);
            my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $dt->strftime('%Y/%m/%d'));
            my $replay_file = sprintf('%s/%s', $replay_path, $filename);
            my $replay_file_base = sprintf('%s/%s', $dt->strftime('%Y/%m/%d'), $filename);

            make_path($replay_path);

            $asset->move_to($replay_file);

            my $incomplete = 0;
            my $br;

            try {
                my $p = WR::Process->new(
                    file    => $replay_file,
                    db      => $self->db('wot-replays'),
                    bf_key  => $self->stash('config')->{wot}->{bf_key},
                    app     => $self->app,
                );
                $m_data = $p->process();
                $br     = $p->pickledata;
            } catch {
                $pe = $_;
                if($pe =~ /incomplete/) {
                    $incomplete = 1;
                } else {
                    unlink($replay_file);
                }
            };

            return $self->r_error(sprintf('Error parsing replay: %s', $pe), $replay_file) if($pe && $incomplete == 0);

            if($incomplete == 0) {
                if(my $or = $self->db('wot-replays')->get_collection('replays')->find_one({ replay_digest => $m_data->{replay_digest} })) {
                    if($or->{site}->{visible}) {
                        return $self->r_error_redirect(sprintf('/replay/%s.html', $or->{_id}->to_string()), $replay_file); 
                    } else {
                        return $self->r_error('That replay exists already', $replay_file);
                    }
                }
                return $self->r_error('That replay seems to be coming from the public test server, we can\'t store those at the moment', $replay_file) if($m_data->{player}->{name} =~ /.*_(EU|NA|RU|SEA|US)$/);
                return $self->r_error(q|Courtesy of WG, this replay can't be stored, it's missing your player ID, and we use that to uniquely identify each player|, $replay_file) if($m_data->{player}->{id} == 0);

                my $rv = $self->nv($m_data->{version});

                return $self->r_error(q|Sorry, but this replay is from an World of Tanks version that is no longer supported|, $replay_file) if($rv < $self->nv('0.8.2'));

                $m_data->{file} = $replay_file_base;
                $m_data->{site} = {
                    description => $self->req->param('description') || undef,
                    uploaded_at => time(),
                    uploaded_by => ($self->is_user_authenticated) ? $self->current_user->{_id} : undef,
                    visible     => ($self->req->param('hide') == 1) ? false : true,
                };

                my $mdl = ($self->stash('config')->{wot}->{version} eq $m_data->{version}) ? 'replays' : sprintf('replays.%s', $m_data->{version});
                $self->model($mdl)->save($m_data, { safe => 1 });

                if($m_data->{site}->{visible} && $m_data->{version} eq $self->stash('config')->{wot}->{version}) {
                    $self->model('wot-replays.newest.www')->insert({ 
                        replay => $m_data->{_id}
                    });
                    $self->model(sprintf('wot-replays.newest.%s', $m_data->{player}->{server}))->insert({
                        replay => $m_data->{_id}
                    });
                }

                my $playerkey = sprintf('%s_%s', $m_data->{player}->{server}, $m_data->{player}->{name});
                $self->model('wot-replays.player.%s')->insert({ 
                    replay          => $m_data->{_id}, 
                    uploaded_at     => $m_data->{site}->{uploaded_at},
                });

                if(defined($m_data->{player}->{clan})) {
                    my $clankey = sprintf('%s_%s', $m_data->{player}->{server}, $m_data->{player}->{clan});
                    $self->model('wot-replays.clan.%s')->insert({ 
                        replay          => $m_data->{_id}, 
                        uploaded_at     => $m_data->{site}->{uploaded_at},
                    });
                }
            }
            $self->render(json => { 
                ok        => 1,
                replay_id => ($incomplete == 0) ? $m_data->{_id}->to_string : undef,
                incomplete => $incomplete,
                ldl        => sprintf('http://dl.wot-replays.org/%s', $filename),
                published => ($self->req->param('hide') == 1) ? 0 : 1,
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
