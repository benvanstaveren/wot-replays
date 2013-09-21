package WR::App::Controller::Replays::Export;
use Mojo::Base 'WR::App::Controller';
use boolean;
use Mojo::JSON;

sub download {
    my $self = shift;
    my $id   = $self->stash('replay_id');

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => bless({ value => $id }, 'MongoDB::OID') })) {
        $self->db('wot-replays')->get_collection('replays')->update({ _id => $replay->{_id} }, { '$inc' => { 'site.downloads' => 1 } });

        # replay->{file} contains the file name including paths that we want so it's still valid
        my $url = Mojo::URL->new(sprintf('http://dl.wt-replays.org/%s', $replay->{file}));
        $self->redirect_to($url->to_string);
    } else {
        $self->render(status => 404, text => 'Not Found');
    }
}

sub csv {
    my $self = shift;
    my $id   = $self->stash('replay_id');
    my $all  = (defined($self->req->param('a')) && $self->req->param('a') > 0) ? 1 : 0;
    my $res  = [];
    my $cols = [qw/player_name vehicle vehicle_type survived health kills damaged spotted damage_done damage_assisted shots hits penetrations xp_earned credits_earned /];

    if(my $replay = $self->db('wot-replays')->get_collection('replays')->find_one({ _id => bless({ value => $id }, 'MongoDB::OID') })) {
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
    } else {
        $self->render(text => 'No such replay');
    }
}

1;
