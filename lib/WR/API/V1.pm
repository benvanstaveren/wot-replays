package WR::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use File::Path qw/make_path/;
use JSON::XS;
use Mango::BSON;
use Scalar::Util qw/blessed/;
use Try::Tiny qw/try catch/;
use WR::Provider::Mapgrid;

sub validate_token {
    my $self    = shift;
    my $token   = $self->req->param('t');
    my $next    = $self->stash('next');

    # cb is only called when the token is valid 
    $self->model('api_token')->find_one({ _id => $token } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($doc)) {
            my $oh = $self->req->headers->header('Origin');
            my $ho = 0;
            
            foreach my $o (@{$doc->{origin}}) {
                if($o eq $oh) {
                    $ho = 1;
                    last;
                }
            }
            if($ho) {
                $self->res->headers->header('Access-Control-Allow-Origin' => $oh);
                $self->res->headers->header('Access-Control-Allow-Headers' => '*');
                $self->$next($doc);
            } else {
                $self->render(json => { ok => 0, error => 'token.unbound' });
            }
        }  else {
            $self->render(json => { ok => 0, error => 'token.invalid' });
        }
    });
}

sub resolve_typecomp {
    my $self    = shift;
    my $types   = $self->req->param('types') || $self->req->param('types[]');
    
    $types = [ split(/,/, $types) ] if(!ref($types));

    $self->render_later;

    $self->model('wot-replays.data.vehicles')->find({ typecomp => { '$in' => [ map { $_ + 0 } @$types ] } })->all(sub {
        my ($coll, $err, $docs) = (@_);
        my $list = {};
        my $reqtypes = { map { $_ => 1 } @$types };

        foreach my $doc (@$docs) {
            if(defined($reqtypes->{$doc->{typecomp}})) {
                $list->{$doc->{typecomp}} = $doc;
            }
        }

        foreach my $type (@$types) {
            $list->{$type} = undef unless(defined($list->{$type}));
        }

        $self->render(json => { ok => 1, data => $list });
    });
}

sub map_details {
    my $self      = shift;
    my $map_ident = $self->stash('map_ident');;

    $self->render_later;

    $self->model('wot-replays.data.maps')->find_one({ _id => $map_ident } => sub {
        my ($c, $e, $d) = (@_);

        if(defined($d)) {
            delete($d->{_id});
            $self->render(json => { ok => 1, data => $d });
        } else {
            $self->render(json => { ok => 0, error => 'not.found', 'not.found' => 'That map does not exist' });
        }
    });
}

sub map_heatmap_data {
    my $self      = shift;
    my $map_ident = $self->stash('map_ident');
    my $gpid      = { 'ctf' => 0, 'domination' => 1, 'assault' => 2 }->{$self->stash('game_type')};
    my $hmtype    = $self->stash('heatmap_type');
    my $bt        = [ split(/,/, $self->stash('bonus_types')) ];

    $self->render_later;
    $self->model('wot-replays.data.maps')->find_one({ _id => $map_ident } => sub {
        my ($c, $e, $d) = (@_);
        if(defined($d)) {
            $self->model(sprintf('wot-replays.hm_%s', $hmtype))->find_one({ _id => $d->{numerical_id}} => sub {
                my ($c, $e, $hmd) = (@_);
                if(defined($hmd)) {
                    my $data = $hmd->{$gpid}; # gameplay id 
                    my $real_data = {};
                    my $pc = 0;
                    foreach my $t (@$bt) {
                        foreach my $cell (keys(%{$data->{$t}})) {
                            $real_data->{$cell} += $data->{$t}->{$cell}; 
                            $pc++;
                        }
                    }
                    $self->render(json => { ok => 1, data => { set => [ map { { cell => $_, value => $real_data->{$_} } } (keys(%$real_data)) ], count => $pc } });
                } else {
                    $self->render(json => { ok => 0, error => 'db.error', 'db.error' => $e });
                }
            });
        } else {
            $self->render(json => { ok => 0, error => 'not.found', 'not.found' => 'That map does not exist' });
        }
    });
}

sub data {
    my $self = shift;
    my $type = $self->stash('type');

    $self->render_later;

    if($type =~ /^(vehicles|equipment|components|consumables)$/) {
        my $m = sprintf('wot-replays.data.%s', $type);
        $self->model($m)->find()->all(sub {
            my ($coll, $err, $docs) = (@_);

            $self->render(json => { ok => (defined($err)) ? 0 : 1, (defined($err)) ? (error => 'data.error', 'data.error' => $err) : (data => $docs) });
        });
    } else {
        $self->render(json => { ok => 0, error => 'data.invalid.type' });
    }
}

sub process_status {
    my $self    = shift;
    my $job_id  = $self->stash('job_id');

    $self->render_later;
    $self->model('wot-replays.jobs')->find_one({ _id => $job_id } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($doc)) {
            $self->render(json => $doc);
        } else {
            $self->render(json => { status => -1, error => 'No such job ID exists' });
        }
    });
}

sub process_replay {
    my $self = shift;
    my $adoc = shift;

    $self->render(json => { ok => 0, error => 'process.not.enabled.for.token' }) and return unless($adoc->{enable_process});

    $self->render_later;

    if(my $upload = $self->req->upload('replay')) {
        $self->render(json => { ok => 0, error => 'not.a.replay.file'}) and return unless($upload->filename =~ /\.wotreplay$/);
        $self->render(json => { ok => 0, error => 'no.postback.url'}) and return unless(defined($self->req->param('postback')));
        my $filename = $upload->filename;
        $filename =~ s/.*\\//g if($filename =~ /\\/);

        my $hashbucket_size = length($filename);
        $hashbucket_size = 7 if($hashbucket_size > 7);
        my $replay_filename = $filename;
        my $replay_path = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $self->hashbucket($filename, $hashbucket_size));
        my $replay_file = sprintf('%s/%s', $replay_path, $filename);
        my $replay_file_base = sprintf('%s/%s', $self->hashbucket($filename, $hashbucket_size), $filename);

        make_path($replay_path);

        my $sha = Digest::SHA1->new();
        $sha->add($upload->asset->slurp);
        $sha->add($replay_filename);       
        my $digest = $sha->hexdigest;

        # set this up as the job id
        $self->model('wot-replays.jobs')->save({
            _id         => $digest,
            uploader    => undef,                       # these will not show up in any upload logs
            ready       => Mango::BSON::bson_false,
            complete    => Mango::BSON::bson_false,
            status      => 0,
            error       => undef,
            replayid    => undef,
            ctime       => Mango::BSON::bson_time,
            status_text => [ ],
            data        => { },
            priority    => 100,
            api         => {
                postback    =>  $self->req->param('postback'),
                flags       =>  {
                    replay      =>  (defined($self->req->param('without-replay'))) ? 0 : 1,
                    packets     =>  (defined($self->req->param('with-packets'))) ? 1 : 0,
                }
            },
        } => sub {
            my ($coll, $err, $oid) = (@_);
            if(defined($oid)) {
                $upload->asset->move_to($replay_file);
                $self->model('wot-replays.jobs')->update({ _id => $digest }, { 
                    '$set' => {
                        'data'  => {
                            file        => $replay_file,
                            file_base   => $replay_file_base,
                            desc        => '',
                            visible     => 1,
                        },
                        ready => Mango::BSON::bson_true,
                    }
                } => sub {
                    my ($coll, $err, $oid) = (@_);

                    if($err) {
                        $self->render(json => { ok => 0, error => 'process.store.fail', 'process.store.fail' => $_ });
                    } else {
                        $self->model('wot-replays.jobs')->find({ complete => Mango::BSON::bson_false, ready => Mango::BSON::bson_true })->count(sub {
                            my ($coll, $err, $count) = (@_);
                            $self->render(json => { ok => 1, queue_position => $count, process_id => $digest });
                        });
                    } 
                });
            } else {    
                $self->render(json => { ok => 0, error => 'process.job.fail' });
            }
        });
    } else {
        $self->render(json => { ok => 0, error => 'no.upload' });
    }
}

1;
