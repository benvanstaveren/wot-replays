package WR::Process::Chatreader;
use Mojo::Base 'WR::Process::Base';
use File::Path qw/make_path/;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use WR::Thunderpush::Server;
use WR::Parser;

has 'config'        => undef;
has 'job'           => undef;

has 'file'          => sub { shift->job->data->{file} };

has 'push'          => sub {
    my $self = shift;
    return WR::Thunderpush::Server->new(host => 'thunderpush.wotreplays.org', secret => $self->config->{thunderpush}->{secret}, key => $self->config->{thunderpush}->{key});
};

sub cleanup {
    my $self = shift;
    my $cb   = shift;

    # process cleanup involves deleting the job, as well as sending the finish packet
    $self->push->send_to_channel('admin' => Mojo::JSON->new->encode({ evt => 'chatreader.finished', data => { session => $self->job->channel } }) => sub {
        $self->job->delete(sub {
            $self->job->unlink;
            return $cb->();
        });
    });
}

sub process_replay {
    my $self    = shift;
    my $parser  = shift;
    my $cb      = shift;

    if(my $stream = $parser->stream()) {
        $self->debug('got parser stream');
        $self->push->send_to_channel('admin' => Mojo::JSON->new->encode({ evt => 'chatreader.init', data => { session => $self->job->channel, size => $stream->len } }) => sub {
            my $timer;
            my $pc = 0;
            my $pos = 0;
            $stream->on(finish => sub {
                my ($s, $r) = (@_);
                Mojo::IOLoop->remove($timer);
                $self->debug('stream finished');
                return $cb->();
            });
            $timer = Mojo::IOLoop->recurring(0 => sub {
                try {
                    $stream->next(sub {
                        my ($s, $packet) = (@_);
                        if(defined($packet) && $packet->type == 0x1f) {
                            $self->push->send_to_channel('admin' => Mojo::JSON->new->encode({ evt => 'chatreader.message', data => { session => $self->job->channel, text => $packet->text } }) => sub {
                                $self->debug('packet pushed');
                            });
                        }
                        
                    });
                    my $np = $stream->position;
                    $pos = $np if($np > $pos);
                    if(++$pc % 256 == 0) {
                        $self->push->send_to_channel('admin' => Mojo::JSON->new->encode({ evt => 'chatreader.position', data => { session => $self->job->channel, position => $pos } }) => sub {
                            $self->debug('position update sent');
                        });
                    }
                } catch {
                    Mojo::IOLoop->remove($timer);
                    $self->error('stream->next error: ', $_);
                    return $cb->();
                };
            });
            $self->debug('set read timer with id ', $timer);
        });
    } else {
        $self->error('Could not obtain replay stream');
        $self->job->error('Could not obtain replay stream');
        return $cb->();
    }
}

1;
