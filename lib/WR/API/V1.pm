package WR::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use WR::Parser;
use WR::Util::PyPickle;
use WR::Process;
use Try::Tiny qw/try catch/;

sub token_valid {
    my $self = shift;
    my $t    = shift;

    if(my $rec = $self->model('wot-replays.api')->find_one({ _id => $t })) {
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

sub data {
    my $self = shift;
    my $type = $self->stash('type');

    if($type =~ /^(vehicles|equipment|components|consumables)$/) {
        my $m    = sprintf('wot-replays.data.%s', $type);
        $self->render(json => { ok => 1, data => [ $self->model($m)->find()->all() ] });
    } else {
        $self->render(json => { ok => 0, error => 'Invalid data type specified' });
    }
}

sub parse {
    my $self = shift;

    if(my $upload = $self->req->upload('replay')) {
        my $asset = $upload->asset;
        if(ref($asset) eq 'Mojo::File::Memory') {
            my $fileasset = Mojo::Asset::File->new();
            $fileasset->add_chunk($asset->slurp);
            $asset = $fileasset; # heh
        }

        my $p = WR::Process->new(
            file    => $asset->handle,
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

        my $data = {
            ok          =>  1,
            replay      =>  $m_data,
        };
        $self->render(json => $data);
    } else {
        $self->render(json => { ok => 0, error => 'No file passed' });
    }
}


            

        
    





    } else {
        $self->render({ ok => 0, error => 'No file sent' });
    }
}

1;
