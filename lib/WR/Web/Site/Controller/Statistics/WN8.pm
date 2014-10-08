package WR::Web::Site::Controller::Statistics::WN8;
use Mojo::Base 'WR::Web::Site::Controller';
use Mango::BSON;

# find the wn8 based on replay's player data,
# which can be easily had from wn8.data.overall key

sub index {
    my $self = shift;

    $self->render_later;

    my $map_function = q|function() {
if(this.wn8 != null && this.wn8.data.overall > 0) emit(this.wn8.data.overall, 1) 
}|;

    my $red_function = q|function(k, v) {
var sum = 0;
v.forEach(function(i) {
    sum += i;
});
return sum;
|;

    # map reduce that into an inline collection, count the total, then obtain percentages 
    
}

1;
