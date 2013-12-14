package WR::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use File::Path qw/make_path/;
use Try::Tiny qw/try catch/;

sub validate_token {
    my $self    = shift;
    my $token   = $self->req->param('t');
    my $next    = $self->stash('next');

    # cb is only called when the token is valid 
    $self->model('api_token')->find_one({ _id => $token } => sub {
        my ($coll, $err, $doc) = (@_);

        if(defined($doc)) {
            # we don't do request counts yet, copy that out of statterbox' API end
            $self->$next();
        }  else {
            $self->render(json => { ok => 0, error => 'Invalid token' });
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

sub data {
    my $self = shift;
    my $type = $self->stash('type');

    $self->render_later;

    if($type =~ /^(vehicles|equipment|components|consumables)$/) {
        my $m = sprintf('wot-replays.data.%s', $type);
        $self->model($m)->find()->all(sub {
            my ($coll, $err, $docs) = (@_);

            $self->render(json => { ok => (defined($err)) ? 0 : 1, (defined($err)) ? (error => $err) : (data => $docs) });
        });
    } else {
        $self->render(json => { ok => 0, error => 'Invalid data type specified' });
    }
}

1;

