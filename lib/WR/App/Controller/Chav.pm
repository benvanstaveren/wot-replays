package WR::App::Controller::Chav;
use Mojo::Base 'WR::App::Controller';

sub index {
    my $self = shift;

    if($self->is_user_authenticated && $self->current_user->{email} eq 'scrambled@xirinet.com') {
        # this is nasty but oh well, we'll group it by replay 
        $self->stash(messages => $self->db('wot-replays')->get_collection('replays.chat')->find({ channel => 'unknown' })->sort({ replay_id => 1, sequence => 1 })->all());
        $self->render(template => 'chav');
    } else {
        $self->render(text => 'Chaaaaav!');
    }
}

1;
