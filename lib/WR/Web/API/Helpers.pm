package WR::Web::API::Helpers;
use strict;
use warnings;
use Mango::BSON;
use Mojo::Parameters;

sub install {
    my $dummy = shift;
    my $app  = shift;

    $app->helper(validate_signature => sub {
        my $self = shift;
        my $skey = shift;
        my $cb   = shift;

        if(defined($self->stash('sig_args'))) {
            my $args = $self->stash('sig_args');

            # make a sorted list of all parameters in their decoded form
            my $list = [];
            foreach my $k (sort(@$args)) {
                push(@$list, sprintf('%s=%s', $k, $self->req->param($k)));
            }
            
        } else {
            return $cb->();
        }
    });

    $app->helper(handle_request => sub {
        my $self = shift;
        


    $app->helper(validate_token => sub {
        my $self    = shift;
        my $cb      = shift;
        my $token   = $self->req->param('t');

        $self->model('api_token')->find_one({ _id => $token } => sub {
            my ($coll, $err, $doc) = (@_);

            if(defined($doc)) {
                if($doc->{request_limit_minute} > 0) {
                    $self->model('api_track')->find({ token => $token })->count(sub {
                        my ($c, $err, $count) = (@_);
                        my $limited = 0;
                        
                        $limited = 1 if($count > $doc->{request_limit_minute});
                        $limited = 0 if($doc->{request_limit_minute} == -1);

                        return $self->render(json => { 'status' => 'error', error => 'request.limit' }, status => 420) if($limited == 1);

                        # validate the signature
                        $self->validate_signature(
                        return $cb->();
                    });
                } else {
                    return $cb->();
                }
            } else {
                return $self->render(json => { 'status' => 'error', error => 'token.invalid' }, status => 403);
            }
        });
    });

    $app->helper(rfrag => sub {
        my $self = shift;
        my $a    = [ 'A'..'Z', 'a'..'z', 0..9 ];
        my $s    = '';

        while(length($s) < 7) {
            $s .= $a->[int(rand(scalar(@$a)))];
        }
        return $s;
    });
}

1;
