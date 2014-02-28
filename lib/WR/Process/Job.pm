package WR::Process::Job;
use Mojo::Base 'Mojo::EventEmitter';
use Mango::BSON;
use Time::HiRes qw/gettimeofday tv_interval/;

has _coll       => undef;
has '_fields'   => sub { [qw/_id complete ctime data error priority ready replayid status status_text uploader locked locked_by locked_at channel type/] };
has [qw/_id complete ctime data error priority ready replayid status status_text uploader locked locked_by locked_at channel type/] => undef;

has '_started'  => undef;

sub delete {
    my $self = shift;
    my $cb   = shift;

    $self->_coll->remove({ _id => $self->_id } => $cb);
}

sub set_status {
    my $self    = shift;
    my $status  = shift;
    my $current;
    my $u = 0;

    $current = $self->status_text;

    my $new = [];

    foreach my $e (@$current) {
        if($e->{id} eq $status->{id}) {
            foreach my $key (keys(%$status)) {
                $e->{$key} = $status->{$key};
            }
            push(@$new, $e);
            $u++;
        } else {
            push(@$new, $e);
        }
    }

    push(@$new, $status) unless($u > 0);

    $self->_coll->update({ _id => $self->_id }, {
        '$set' => {
            status_text => $new,
        }
    } => sub {
        # fire and forget, even though it may mean we clobber the status repeatedly 
    });

    $self->status_text($new);
}


sub load {
    my $self = shift;
    my $cb   = shift;

    $self->_coll->find_one({ _id => $self->_id } => sub {
        my ($c, $e, $d) = (@_);

        if(defined($e) || !defined($d)) {
            return $cb->($self, $e);
        } else {
            foreach my $f (@{$self->_fields}) {
                $self->$f($d->{$f});
            }
            return $cb->($self, undef);
        }
    });
}

sub lock {
    my $self = shift;
    my $cb   = shift;

    $self->_coll->update({ _id => $self->_id }, { 
        '$set' => {
            locked      => Mango::BSON::bson_true,
            locked_by   => $$,
            locked_at   => Mango::BSON::bson_time(),
        }
    } => sub {
        my ($c, $e, $d) = (@_);
        
        if(defined($e)) {
            return $cb->($self, $e);
        } else {
            return $cb->($self);
        }
    });
}

sub start {
    my $self = shift;

    $self->_started([gettimeofday]);
}

sub elapsed { return tv_interval(shift->_started) }

sub set_error {
    my $self = shift;
    my @msg  = (@_); 
    my $cb   = pop(@msg);

    my $message = join('', @msg);
    $message =~ s/(.*)\sat\s.*/$1/g;

    $self->_coll->update({ _id => $self->_id }, {
        '$set' => {
            complete    =>  Mango::BSON::bson_true,
            elapsed     =>  $self->elapsed,
            status      =>  -1,
            error       =>  $message,
            locked      =>  Mango::BSON::bson_false,
        },
    } => $cb);
}

sub set_complete {
    my $self    = shift;
    my $replay  = shift;
    my $cb      = shift;

    $self->_coll->update({ _id => $self->_id }, {
        '$set' => {
            complete    =>  Mango::BSON::bson_true,
            elapsed     =>  $self->elapsed,
            status      =>  1,
            replayid    =>  $replay->get('_id'),
            banner      =>  $replay->get('site.banner'),
            file        =>  $replay->get('file'),
            minimal     =>  ($replay->get('site.minimal')) ? Mango::BSON::bson_true : Mango::BSON::bson_false,
        },
    } => $cb);
}

sub unlink { CORE::unlink(shift->data->{file}) }

1;
