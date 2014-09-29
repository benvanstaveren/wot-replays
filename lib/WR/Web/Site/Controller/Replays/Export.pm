package WR::Web::Site::Controller::Replays::Export;
use Mojo::Base 'WR::Web::Site::Controller';
use boolean;
use Mojo::JSON;

sub download {
    my $self = shift;
    my $id   = $self->stash('replay_id');

    $self->render_later;
    $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($id) } => sub {
        my ($c, $e, $replay) = (@_);
        if($e) {
            $self->render(status => 404, text => 'Not Found');
        } else {
            my $url = Mojo::URL->new(sprintf('%s/%s', $self->stash('config')->{urls}->{replays}, $replay->{file}));
            $self->redirect_to($url->to_string);
            #$self->model('wot-replays.replays')->update({ _id => Mango::BSON::bson_oid($id) }, { '$inc' => { 'site.downloads' => 1 }} => sub {
            #    my ($c, $e, $d) = (@_);
            #});
        }
    });
}

sub csv {
    my $self = shift;
    my $id   = $self->stash('replay_id');
    my $all  = (defined($self->req->param('a')) && $self->req->param('a') > 0) ? 1 : 0;
    my $res  = [];
    my $cols = [qw/player_name vehicle vehicle_type survived health kills damaged spotted damage_done damage_assisted shots hits penetrations xp_earned credits_earned /];

    $self->render_later;

    $self->model('wot-replays.replays')->find_one({ _id => Mango::BSON::bson_oid($id) } => sub {
        my ($c, $e, $replay) = (@_);

        $self->render(text => 'No such replay') and return if($e);

        my $playerteam = $replay->{player}->{team}; 

        foreach my $vid (keys(%{$replay->{vehicles}})) {
            my $v = $replay->{vehicles}->{$vid};
            next if(!$all && $v->{team} != $playerteam);

            my $row = [];
            push(@$row, sprintf('"%s"', $v->{name}));
            push(@$row, sprintf('"%s"', $v->{vehicleType}->{label}));
            push(@$row, sprintf('"%s"', $v->{vehicleType}->{type}));
            push(@$row, sprintf('%d', ($v->{health} > 0 && $v->{killerID} == 0) ? 1 : 0));
            for(qw/health kills damaged spotted/) {
                push(@$row, sprintf('%d', $v->{$_} + 0));
            }
            push(@$row, sprintf('%d', $v->{damageDealt} + 0));
            push(@$row, sprintf('%d', $v->{damageAssisted} + 0));
            for(qw/shots hits/) {
                push(@$row, sprintf('%d', $v->{$_} + 0));
            }
            push(@$row, sprintf('%d', $v->{pierced} + 0));
            push(@$row, sprintf('%d', $v->{xp} + 0));
            push(@$row, sprintf('%d', $v->{credits} + 0));
            push(@$res, $row);
        }
        $self->stash(cols => $cols, rows => $res);

        # construct the csv
        my $csv = '"' . join('","', @$cols) . '"' . "\n";

        foreach my $row (@$res) {
            $csv .= join(',', @$row);
            $csv .= "\n";
        }

        $self->render(text => $csv, content_type => 'text/csv', format => 'csv');
    });
}

1;
