package WR::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use WR::Parser;
use WR::Util::PyPickle;
use WR::Process;
use WR::ServerFinder;
use WR::Res::Achievements;
use boolean;
use Try::Tiny qw/try catch/;

sub token_valid {
    my $self = shift;
    my $t    = shift;

    if(my $rec = $self->model('wot-replays.api')->find_one({ _id => $t })) {
        $self->stash('token_ident' => $rec->{ident});
        return 1;
    } else {
        return undef;
    }
}

sub check_token {
    my $self = shift;
    my $t    = $self->req->param('t');

    # find out if the token is allowed to access and what the limits are
    if(my $rv = $self->token_valid($t)) {
        if($rv == -1) {
            # out of requests
            $self->render(json => { ok => 0, error => 'Request limit exceeded' }, status => 420);
        } else {
            return 1;
        }
    } else {
        # token's not valid so return the proper HTTP code as well
        $self->render(json => { ok => 0, error => 'Token Invalid' }, status => 401);
        return 0;
    }
}

sub fuck_boolean {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_boolean($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_boolean($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_boolean($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(boolean::isBoolean($obj->{$field})) {
                $obj->{$field} = ($obj->{$field}) ? Mojo::JSON->true : Mojo::JSON->false;
            }
        }
        return $obj;
    }
}

sub data {
    my $self = shift;
    my $type = $self->stash('type');

    if($type =~ /^(vehicles|equipment|components|consumables)$/) {
        my $m = sprintf('wot-replays.data.%s', $type);
        my $a = [ $self->model($m)->find()->all() ];
        $self->render(json => { ok => 1, data => $self->fuck_boolean($a) });
    } elsif($type eq 'players') {
        $self->render(json => { ok => 1, data => $self->fuck_boolean([ $self->model('wot-replays.cache.server_finder')->find()->all() ]) });
    } else {
        $self->render(json => { ok => 0, error => 'Invalid data type specified' });
    }
}

sub parse_rpc {
    my $self = shift;
    my $job  = {};

    if(my $replay_url = $self->req->param('replay_url')) {
        if(my $postback_url = $self->req->param('postback_url')) {
            my $job = {
                _id             => MongoDB::OID->new()->to_string,
                replay_url      => $replay_url,
                postback_url    => $postback_url,
                store           => ($self->req->param('ns')) ? 0 : 1,
                complete        => false,
                processing      => false,
                created         => time(),
                completed       => 0,
            };

            $self->model('wot-replays.process')->save($job);
            $self->render(json => { ok => 1, job_id => $job->{_id} });
        } else {
            $self->render(json => { ok => 0, error => '[missing]: postback url' });
        }
    } else {
        $self->render(json => { ok => 0, error => '[missing]: replay url' });
    }
}

sub parse {
    my $self = shift;
    my $s    = ($self->req->param('ns')) ? 0 : 1;

    if(my $upload = $self->req->upload('replay')) {
        my $asset = $upload->asset;
        if(ref($asset) eq 'Mojo::File::Memory') {
            my $fileasset = Mojo::Asset::File->new();
            $fileasset->add_chunk($asset->slurp);
            $asset = $fileasset; # heh
        }

        my $p = WR::Process->new(
            file    => $asset->path,
            db      => $self->db('wot-replays'),
            bf_key  => $self->stash('config')->{wot}->{bf_key},
        );

        my $m_data;
        try {
            $m_data = $p->process();
        } catch {
            $self->render(json => { ok => 0, error => "[process]: $_" });
        };
        return unless(defined($m_data));

        my $filename = $upload->filename;
        $filename =~ s/.*\\//g if($filename =~ /\\/);
        $filename =~ s/.*\///g if($filename =~ /\//);
        $m_data->{file} = $filename;
        
        my $url = undef;

        if($s == 1) {
            unless($self->model('wot-replays.replays')->find_one({ replay_digest => $m_data->{replay_digest}})) {
                my $replay_file = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $filename);
                $asset->move_to($replay_file);
                $self->model('wot-replays.replays')->save({
                    %$m_data,
                    site => {
                        description => undef,
                        uploaded_at => time(),
                        uploaded_by => undef,
                        ident       => $self->stash('token_ident'),
                        visible     => true,
                    }
                });
                $url = sprintf('http://www.wot-replays.org/replay/%s.html', $m_data->{_id}->to_string);
            } else {
                # still return it
                $url = sprintf('http://www.wot-replays.org/replay/%s.html', $m_data->{_id}->to_string);
            }
        } else {
            $asset->cleanup;
        }
        my $data = {
            ok          =>  1,
            replay      =>  $self->fuck_boolean($m_data),
        };
        $data->{url} = $url if($s == 1 && defined($url));
        $self->render(json => $data);
    } else {
        $self->render(json => { ok => 0, error => 'no such upload "replay"' });
    }
}

1;
