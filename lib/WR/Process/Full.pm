package WR::Process::Full;
use Mojo::Base 'WR::Process::Base';
use WR::Parser;
use WR::Res::Achievements;
use WR::Provider::ServerFinder;
use WR::Provider::Imager;
use WR::Provider::Panelator;
use WR::HashTable;
use WR::Constants qw/nation_id_to_name decode_arena_type_id ARENA_PERIOD_BATTLE gameplay_id_to_name/;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use WR::QuickDB;
use Data::Dumper;

use Mango;
use Mango::BSON;
use Scalar::Util qw/blessed/;
use Try::Tiny qw/try catch/;
use File::Path qw/make_path/;

use constant PARSER_VERSION => 0; # yeah
use constant PACKET_VERSION => 1; # even more yeah

has [qw/config job log/] => undef;

has 'mango'         => sub {
    my $self = shift;
    return Mango->new($self->config->{mongodb}->{host});
};
    
has 'banner_path'   => sub { return shift->config->{paths}->{banners} };
has 'packet_path'   => sub { return shift->config->{paths}->{packets} };
has 'banner'        => 1;

has 'packets'       => sub { [] };
has 'ua'            => sub { Mojo::UserAgent->new };

has [qw/_components _consumables _maps _vehicles/] => undef;

has 'push'          => sub {
    my $self = shift;
    return WR::Thunderpush::Server->new(host => 'push.wotreplays.org', secret => $self->config->{thunderpush}->{secret}, key => $self->config->{thunderpush}->{key});
};


sub _preload {
    my $self = shift;
    my $cb   = shift;

    my $delay = Mojo::IOLoop->delay(sub {
        $self->debug('_preload delay cb');
        return $cb->();
    });

    my $preload = [ 'components', 'consumables', 'maps', 'vehicles' ];
    foreach my $type (@$preload) {
        my $end = $delay->begin(0);
        my $attr = sprintf('_%s', $type);
        $self->debug('preloading ', $type);
        $self->model(sprintf('wot-replays.data.%s', $type))->find()->all(sub {
            my ($c, $e, $d) = (@_);
            $self->$attr(WR::QuickDB->new(data => $d));
            $self->debug('preloading ', $type, ' callback');
            $end->();
        });
        $self->debug('post preloading ', $type);
    }
}

sub fix_server {
    my $self = shift;
    my $s    = shift;

    return 'asia' if($s eq 'sea');
    return $s;
}

sub get_consumable {
    my $self = shift;
    my $id   = shift;

    return $self->_consumables->get(wot_id => $id);
}

sub get_component {
    my $self = shift;
    my $type = shift;
    my $country = shift;
    my $id = shift;

    return $self->_components->get_multi(component => $type, country => $country, component_id => $id);
}

sub add_packet {
    my $self    = shift;
    my $packet  = shift;

    push(@{$self->packets}, (blessed($packet)) ? $packet->to_hash : $packet);
}

sub model {
    my $self = shift;
    my $m    = shift;

    my ($db, $coll) = split(/\./, $m, 2);

    return $self->mango->db($db)->collection($coll);
}

sub process_replay {
    my $self   = shift;
    my $parser = shift;
    my $cb     = shift;

    $self->debug('process_replay top');

    $self->emit('state.prepare.start');
    $self->_preload(sub {
        $self->emit('state.prepare.finish');
        try {
            $self->_real_process($parser => $cb);
        } catch {
            my $e = $_;
            $self->job->set_error('Process error: ', $e);
            $self->error('Process error: ', $e);
            $cb->($self, $e, undef);
        };
    });
}

# emit also dispatches to thunderpush
sub emit {
    my $self = shift;
    my $key  = shift;
    my $data = shift;
    my $cb   = shift;

    $data->{job_id} = $self->job->_id;

    $self->push->send_to_channel('site' => Mojo::JSON->new->encode({ evt => $key,  data => $data}) => sub {
        $self->SUPER::emit($key => $data);
        return $cb->() if(defined($cb));
    });
}

sub _stream_replay {
    my $self    = shift;
    my $parser  = shift;
    my $replay  = shift;
    my $cb      = shift;
    my $pcount  = 0;

    # set up game; game->start will set up a timer that will do some opportunistic reading
    # for stream->next, the finish event from game will complete the initial replay step. 
    if(my $game = $parser->game()) {
        $game->on('replay.position' => sub {
            my ($s, $v) = (@_);
            
            if(++$pcount % 100 == 0) {
                $self->emit('state.streaming.progress' => { count => $v } => sub {
                    # no-op but we want it to not block
                });
            }
        });
        $game->on('game.version' => sub {
            my ($s, $v) = (@_); 
            $replay->set('game.version' => $v);
        });
        $game->on('game.version_n' => sub {
            my ($s, $v) = (@_);
            $replay->set('game.version_numeric' => $v + 0);
        });
        $game->on('recorder.name' => sub {
            my ($s, $v) = (@_);
            $replay->set('game.recorder.name' => $v);
        });
        $game->on('recorder.account_id' => sub {
            my ($s, $v) = (@_);
            $replay->set('game.recorder.account_id' => $v + 0);
        });
        $game->on('recorder.id' => sub {
            my ($s, $v) = (@_);
            $replay->set('game.recorder.id' => $v + 0);
        });
        $game->on('arena.initialize' => sub {
            my ($s, $init) = (@_);

            $replay->set('game.battle_level'    => (defined($init->{battleLevel})) ? $init->{battleLevel} + 0 : undef);
            $replay->set('game.opponents'       => (defined($init->{opponents})) ? $init->{opponents} : undef);
            $replay->set('game.arena_id'        => $init->{arena_unique_id} . '');
            $replay->set('game.started'         => undef);
            $replay->set('game.duration'        => undef);
            $replay->set('game.winner'          => undef);
            $replay->set('game.bonus_type'      => $init->{bonus_type} + 0);
            $replay->set('game.finish_reason'   => undef);
            $replay->set('game.type'            => gameplay_id_to_name($init->{gameplay_id}));
            $replay->set('game.type_n'          => $init->{gameplay_id});
            $replay->set('game.map'             => $init->{map_id});
            if(my $d = $self->_maps->get(numerical_id => $init->{map_id})) {
                $replay->set('game.map_extra' => {
                    ident   => $d->{_id},
                    slug    => $d->{slug},
                    icon    => $d->{icon},
                    label   => $d->{label},
                    geometry => [ $d->{attributes}->{geometry}->{bottom_left}, $d->{attributes}->{geometry}->{upper_right} ],
                });
            }
        });

        # here's some additional bits and pieces that we are interested in to write packet files
        for my $event ('player.position', 'player.health', 'player.tank.destroyed', 'player.chat', 'arena.period', 'player.tank.damaged', 'arena.initialize', 'cell.attention', 'arena.base_points', 'arena.base_captured', 'arena.avatar_ready') {
            $game->on($event => sub {
                my ($s, $v) = (@_);
                $self->add_packet($v);
            });
        }
        # subscribe some duplicates for other things
        $game->on('player.chat' => sub {
            my ($game, $chat) = (@_);
            $replay->append('chat', $chat->{text});
        });
        $game->on('setup.roster' => sub {
            my ($g, $v) = (@_);

            $replay->set('roster' => $v);
        });
        $game->on(finish => sub {
            my ($game, $reason) = (@_);
            $self->emit('state.streaming.finish' => { total => $game->stream->len } => sub {
                if($reason->{ok} == 0) {
                    return $cb->(undef, $reason->{reason});
                } else {
                    $replay->set('game.recorder.consumables' => $game->vcons_initial);
                    $replay->set('game.recorder.ammo'        => $game->vshells_initial);

                    $replay->set('temp.bperf'       => $game->bperf);
                    $replay->set('temp.stats'       => $game->statistics);
                    $replay->set('temp.personal'    => $game->personal);

                    return $cb->($replay, undef);
                }
            });
        });
        $self->emit('state.streaming.start' => { total => $game->stream->len } => sub {
            $game->start;
        });
    } else {
        return $cb->(undef, 'Could not stream replay');
    }
}

sub _setup_legacy_state_handlers {
    my $self = shift;

    $self->on('state.prepare.start' => sub {
        $self->job->set_status({
            id      =>  'prepare',
            text    =>  'Preparing replay...',
            i18n    =>  'process.state.prepare',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        });
    });
    $self->on('state.prepare.finish' => sub {
        $self->job->set_status({
            id      =>  'prepare',
            done    =>  Mango::BSON::bson_true,
        });
    });
    $self->on('state.streaming.start' => sub {
        my ($o, $t) = (@_);
        $self->job->set_status({
            id      =>  'streaming',
            text    =>  'Streaming packets',
            i18n    =>  'process.state.streaming',
            type    =>  'progress',
            count   =>  0,
            total   =>  $t->{total},
            done    =>  Mango::BSON::bson_false,
        });
    });
    $self->on('state.streaming.progress' => sub {
        my ($o, $d) = (@_);
        $self->job->set_status({
            id      =>  'streaming',
            count   =>  $d->{count},
        });
    });
    $self->on('state.streaming.finish' => sub {
        my ($o, $t) = (@_);
        $self->job->set_status({
            id      =>  'streaming',
            count   =>  $t->{total},
            total   =>  $t->{total},
            done    =>  Mango::BSON::bson_true
        });
    });
    $self->on('state.generatebanner.start' => sub {
        $self->job->set_status({
            id      =>  'generatebanner',
            text    =>  'Generating banner...',
            i18n    =>  'process.state.generatebanner',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        });
    });
    $self->on('state.generatebanner.finish' => sub {
        $self->job->set_status({
            id      =>  'generatebanner',
            done    =>  Mango::BSON::bson_true,
        });
    });
    $self->on('state.packet.save.start' => sub {
        $self->job->set_status({
            id      =>  'packetsave',
            text    =>  'Saving packets to disk...',
            i18n    =>  'process.state.packetsave',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        });
    });
    $self->on('state.packet.save.finish' => sub {
        $self->job->set_status({
            id      =>  'packetsave',
            done    =>  Mango::BSON::bson_true,
        });
    });
    $self->on('state.wn7.start' => sub {
        my ($o, $t) = (@_);
        $self->job->set_status({
            id      =>  'wn7',
            text    =>  'Fetching ratings from Statterbox',
            i18n    =>  'process.state.rating',
            type    =>  'progress',
            count   =>  0,
            total   =>  $t->{total},
            done    =>  Mango::BSON::bson_false,
        });
    });
    $self->on('state.wn7.start' => sub {
        my ($o, $d) = (@_);
        $self->job->set_status({
            id      =>  'wn7',
            count   =>  $d->{count},
        });
    });
    $self->on('state.wn7.finish' => sub {
        my ($o, $t) = (@_);
        $self->job->set_status({
            id      =>  'wn7',
            count   =>  $t->{total},
            total   =>  $t->{total},
            done    =>  Mango::BSON::bson_true,
        });
    });
}

sub _with_battle_result {
    my $self    = shift;
    my $parser  = shift;
    my $replay  = shift;
    my $br      = shift;
    my $cb      = shift;

    $self->process_battle_result($replay, $br, sub {
        if(my $replay = shift) {
            # fix up the replay with some additional junk
            if($replay->get('game.winner') == 0) {
                $replay->set('game.victory' => -1); # draw
            } else {
                $replay->set('game.victory' => ($replay->get('game.winner') == $replay->get('game.recorder.team')) ? 1 : 0);
            }
            $replay->set('stats.damageAssisted' => $replay->get('stats.damageAssistedTrack') + $replay->get('stats.damageAssistedRadio'));

            # this really oughta move into the stream events
            if($replay->get('game.version_numeric') < $self->config->{wot}->{min_version}) {
                $self->job->unlink;
                $self->job->set_error('That replay is from an older version of World of Tanks which we cannot process...');
                return $cb->($self, undef, 'That replay is from an older version of World of tanks which we cannot process...');
            } elsif($replay->get('game.version_numeric') > $self->config->{wot}->{version_numeric}) {
                $self->job->unlink;
                $self->job->set_error('That replay is from a newer version of World of Tanks which we cannot process...');
                return $cb->($self, undef, 'That replay is from a newer version of World of tanks which we cannot process...');
            } else {
                $replay->set('digest' => $self->job->_id);
                $replay->set('site.visible' => ($self->job->data->{visible} < 1) ? Mango::BSON::bson_false : Mango::BSON::bson_true);
                $replay->set('site.privacy' => $self->job->data->{privacy} || 0);
                $replay->set('site.description' => (defined($self->job->data->{desc}) && length($self->job->data->{desc}) > 0) ? $self->job->data->{desc} : undef);
                $replay->set('site.uploaded_at' => Mango::BSON::bson_time());
                $replay->set('file' => $self->job->data->{file_base});
                if($replay->get('game.bonus_type') == 5) {
                    $self->debug('fix CW privacy');
                    $replay->set('site.visible' => Mango::BSON::bson_false);
                    $replay->set('site.privacy' => 3);
                }

                # see if we're processing an orphan, it's a bit of a waste to do it after all the work we went through,
                # but eh. 
                if($replay->get('site.orphan')) {
                    # fix that up later, for now we'll just replace the entire thing, likes, downloads, etc. and all
                }

                # create the panel - we'll switch to using data mode here
                my $data = $replay->data;
                $data->{panel} = WR::Provider::Panelator->new->panelate($data);
                $self->model('wot-replays.replays')->save($data => sub {
                    my ($c, $e, $d) = (@_);

                    if(defined($e)) {
                        $self->error('full store fail: ', $e);
                        $self->job->set_error('store fail: ', $e);
                        return $cb->($self, undef, $e);
                    } else {
                        $self->debug('full replay saved ok');
                        $self->job->set_complete($replay => sub {
                            $self->debug('full job complete cb');
                            return $cb->($self, $replay, undef);
                        });
                    }
                });
            }
        }
    });
}

sub _without_battle_result {
    my $self   = shift;
    my $parser = shift;
    my $replay = shift;
    my $cb      = shift;

    $self->debug('replay has no battle result, doing process_minimal');
    $self->process_minimal($parser => $replay => sub {
        if(my $replay = shift) {
            # store it the way it's come out
            my $data = $replay->data;
            $data->{panel} = WR::Provider::Panelator->new->panelate($data);
            $self->model('wot-replays.replays')->save($data => sub {
                my ($c, $e, $d) = (@_);

                if(defined($e)) {
                    $self->error('ninimal store fail: ', $e);
                    $self->job->set_error('ninimal store fail: ', $e);
                    return $cb->($self, undef, $e);
                } else {
                    $self->debug('ninimal replay saved ok');
                    $self->job->set_complete($replay => sub {
                        $self->debug('ninimal job complete cb');
                        return $cb->($self, $replay, undef);
                    });
                }
            });
        }
    });
}

sub _real_process {
    my $self   = shift;
    my $parser = shift;
    my $cb     = shift;

    my $replay = WR::HashTable->new(data => {});
    if(defined($self->job->replayid)) {
        $self->debug('job has existing replayid');
        $replay->set('_id' => $self->job->replayid); # we're re-doing an existing replay
        $replay->set('site.orphan' => Mango::BSON::bson_true); # not entirely true, but we might as well abuse the flag for it
    } else {
        $self->debug('job for new replay');
        $replay->set('_id' => Mango::BSON::bson_oid);
    }

    # set up a couple of handlers for our state events, we still update the job with it
    $self->_setup_legacy_state_handlers;
    $self->debug('set up legacy state handlers');

    # couple stages to the process
    $self->_stream_replay($parser, $replay, sub {
        my ($replay, $error) = (@_);

        $self->debug('stream replay callback with error ', $error, ' replay ', $replay);

        if(defined($error)) {
            $self->job->set_error($error);
            $self->error($error);
            $cb->($self, undef, $error);
        } else {
            # figure out if the replay has a battle result, if it doesn't, just store
            # it as a minimal replay
            if($parser->has_battle_result) {
                $self->debug('replay has battle result');
                $self->_with_battle_result($parser, $replay, $parser->get_battle_result, $cb);
            } else {
                $self->debug('replay has no battle result, attempting lookup');
                # see if we happen to have an uploaded battle result for this replay
                my $arena_id = $replay->get('game.arena_id') . '';

                $self->model('wot-replays.battleresults')->find_one({
                    'arena_id'                           => $arena_id,
                    'battle_result.personal.accountDBID' => $replay->get('game.recorder.account_id')
                } => sub {
                    my ($c, $e, $d) = (@_);

                    if(defined($e)) {
                        $self->error('Error during lookup of battle result: ', $e);
                        $self->_without_battle_result($parser, $replay, $cb);
                    } elsif(!defined($d)) {
                        $self->debug('Could not find a stored battle result for this replay, using: ', $arena_id, ' and dbid: ', $replay->get('game.recorder.account_id'));
                        $self->_without_battle_result($parser, $replay, $cb);
                    } else {
                        $self->debug('Found stored battle result');
                        $d->{battle_result}->{arenaUniqueID} = $arena_id; # yeah...
                        $self->_with_battle_result($parser, $replay, $d->{battle_result}, $cb);
                    }
                });
            }
        }
    });
}

sub process_minimal {
    my $self   = shift;
    my $parser = shift;
    my $replay = shift;
    my $cb     = shift;

    # to figure out the arena start time, we'll have to dig it out of the first block 
    # also use the temp.bperf, temp.stats, and temp.personal dicts to at least pull some stats
    # in 

    my $temp = { %{$replay->get('temp')} }; # shallow 
    delete($replay->data->{temp}); # yeah...


    foreach my $key (keys(%{$temp->{personal}})) {
        $replay->set(sprintf('stats.%s', $key) => $temp->{personal}->{$key});
    }
    $replay->set('site.minimal'     => Mango::BSON::bson_true);
    $replay->set('site.visible'     => Mango::BSON::bson_false);
    $replay->set('site.privacy'     => 1); # unlisted
    $replay->set('game.server'      => WR::Provider::ServerFinder->new->get_server_by_id($replay->get('game.recorder.account_id')));

    $self->debug('process minimal complete, replay data now: ', Dumper($replay->data));

    $cb->($replay);
}

sub process_battle_result {
    my $self          = shift;
    my $replay        = shift;
    my $battle_result = shift;
    my $cb            = shift;

    $self->finalize_roster($replay, $battle_result);

    $replay->set('stats'                => $battle_result->{personal});
    $replay->set('game.duration'        => $battle_result->{common}->{duration} + 0);
    $replay->set('game.started'         => Mango::BSON::bson_time($battle_result->{common}->{arenaCreateTime} * 1000));
    $replay->set('game.winner'          => $battle_result->{common}->{winnerTeam});
    $replay->set('game.finish_reason'   => $battle_result->{common}->{finishReason});

    $replay->set('game.recorder.team'       => $battle_result->{personal}->{team} + 0);
    $replay->set('game.recorder.survived'   => ($battle_result->{personal}->{deathReason} == -1) ? Mango::BSON::bson_true : Mango::BSON::bson_false);
    $replay->set('game.recorder.killer'     => ($battle_result->{personal}->{killerID} > 0) ? $battle_result->{personal}->{killerID} : undef);
    $replay->set('game.recorder.lifetime'   => $battle_result->{personal}->{lifeTime} + 0);

    my $consumables     = [];
    my $ammo            = [];

    my $vcons_initial   = $replay->get('game.recorder.consumables');
    my $vshells_initial = $replay->get('game.recorder.ammo');

    foreach my $tc (keys(%$vcons_initial)) {
        if($tc > 0) {
            my $a = parse_int_compact_descr($tc);
            if(my $c = $self->get_consumable($a->{id})) {
                push(@$consumables, $c);
            }
        }
    }

    # ammo is a bit different since the array needs to be hashes of { id => typeid, count => count }
    foreach my $id (keys(%$vshells_initial)) {
        my $tc = parse_int_compact_descr($id);
        if(my $a = $self->get_component('shells', nation_id_to_name($tc->{country}), $tc->{id})) {
            push(@$ammo, {
                ammo  => $a,
                count => $vshells_initial->{$id}->{count},
            });
        }
    }
    
    $replay->set('game.recorder.consumables' => $consumables);
    $replay->set('game.recorder.ammo'        => $ammo);

    my $delay = Mojo::IOLoop->delay(sub {
        $self->debug('process_battle_result main delay cb');
        $cb->($replay);
    });

    sub _generate_banner {
        my $self = shift;
        my $replay = shift;
        my $end = shift;

        $self->emit('state.generatebanner.start' => {} => sub {
            $self->debug('preparing banner');
            $self->generate_banner($replay => sub {
                my $image = shift;
                $self->emit('state.generatebanner.finish' => {} => sub {
                    $replay->set('site.banner' => $image);
                    $end->();
                });
            });
        });
    }

    sub _misc {
        my $self = shift;
        my $replay = shift;
        my $end = shift;

        $replay->set('game.server'          => WR::Provider::ServerFinder->new->get_server_by_id($replay->get('game.recorder.account_id')));
        $replay->set('game.recorder.index'  => $replay->get('players')->{$replay->get('game.recorder.name')});

        my $tc = {};
        foreach my $entry (@{$replay->get('roster')}) {
            next unless(length($entry->{player}->{clanAbbrev}) > 0);
            $tc->{$entry->{player}->{clanAbbrev}}++;
        }
        $replay->set('involved' => {
            players     => [ keys(%{$replay->get('players')}) ],
            clans       => [ keys(%$tc) ],
            vehicles    => [ map { $_->{vehicle}->{ident} } @{$replay->get('roster')} ],
        });
        # noooo... cock!
        # $replay->set('version' => $parser->version);
        $end->();
    }

    sub _packetstore {
        my $self = shift;
        my $replay = shift;
        my $end = shift;

        $self->debug('storing packets for replay');
        $self->emit('state.packet.save.start' => {} => sub {
            my $base_path = sprintf('%s/%s', $self->packet_path, $self->hashbucket($replay->get('_id') . '', 7));
            make_path($base_path) unless(-e $base_path);
            my $packet_file = sprintf('%s/%s.json', $base_path, $replay->get('_id') . '');
            if(my $fh = IO::File->new(sprintf('>%s', $packet_file))) {
                my $json = Mojo::JSON->new();
                $fh->print($json->encode($self->packets));
                $fh->close;
                $self->debug('wrote packets to file');
                $replay->set('packets' => sprintf('%s/%s.json', $self->hashbucket($replay->get('_id') . '', 7), $replay->get('_id') . ''));
                $self->emit('state.packet.save.finish' => {} => sub {
                    $end->();
                });
            } else {
                $self->debug('could not write packets to file');
                $replay->set('packets' => undef);
                $self->emit('state.packet.save.finish' => {} => sub {
                    $end->();
                });
            }
        });
    }

    sub _ratings {
        my $self = shift;
        my $replay = shift;
        my $end = shift;

        $self->emit('state.wn7.start' => { total => scalar(keys(%{$replay->get('players')})) } => sub {
            my $ratingdelay = Mojo::IOLoop->delay(sub {
                $self->debug('ratingdelay cb');
                $self->emit('state.wn7.finish' => { total => scalar(@{$replay->get('roster')}) } => sub { 
                    $self->debug('ratingdelay emit cb');
                    $end->();
                });
            });

            $self->ua->inactivity_timeout(120);
            
            my $count = 0;
            foreach my $entry (@{$replay->get('roster')}) {
                my $url = 'http://api.statterbox.com/wot/account/wn8';
                my $rend = $ratingdelay->begin(0);
                my $form = {
                    application_id  => $self->config->{'statterbox'}->{server},
                    account_id      => $entry->{player}->{accountDBID},
                    cluster         => $self->fix_server($replay->get('game.server')),
                };
                $self->debug('getting wn8 from statterbox via ', $url, ' -> ', Dumper($form));
                $self->ua->post($url => form => $form => sub {
                    my ($ua, $tx) = (@_);

                    $self->debug('callback for ', $url);

                    if(my $res = $tx->success) {
                        if($res->json->{status} eq 'ok') {
                            $self->debug('wn8 res ok');
                            my $data = $res->json->{data};
                            my $wn8  = $data->{$entry->{player}->{accountDBID}};
                            if(defined($wn8))  {
                                $entry->{wn8} = { 
                                    available => Mango::BSON::bson_true,
                                    data => { overall => $wn8->{wn8} }
                                };
                            } else {
                                $entry->{wn8} = { 
                                    available => Mango::BSON::bson_false,
                                    data => { overall => 0 }
                                };
                            }
                        } else {
                            $self->debug('wn8 res error: ', Dumper($res->json));
                            $entry->{wn8} = { 
                                available => Mango::BSON::bson_false,
                                data => { overall => 0 }
                            };
                        }
                    } else {
                        my ($err, $code) = $tx->error;
                        $self->debug('wn8 res not success, code: ', $code, ' err: ', $err);
                        $entry->{wn8} = { 
                            available => Mango::BSON::bson_false,
                            data => { overall => 0 }
                        };
                    }
                    $replay->set('wn8' => $entry->{wn8}) if($entry->{player}->{name} eq $replay->get('game.recorder.name'));
                    $self->emit('state.wn7.progress' => { count => ++$count, total => scalar(@{$replay->get('roster')}) } => sub {
                        $rend->();
                    });
                });
            }

            my $brend = $ratingdelay->begin();
            my $roster = $replay->get('roster')->[ $replay->get('players')->{$replay->get('game.recorder.name')} ];
            my $url = sprintf('http://statterbox.com/api/v1/%s/calc/wn8?t=%d&frags=%d&damage=%d&spots=%d&defense=%d',
                '5299a074907e1337e0010000',
                $roster->{vehicle}->{typecomp},
                $replay->get('stats.kills') + 0,
                $replay->get('stats.damageDealt') + 0,
                $replay->get('stats.spotted') + 0,
                $replay->get('stats.droppedCapturePoints') + 0
                );

            $self->debug(sprintf('Getting battle WN8 from: %s', $url));
            $self->ua->get($url => sub {
                my ($ua, $tx) = (@_);
                if(my $res = $tx->success) {
                    $replay->set('wn8.data.battle' => $res->json('/wn8'));
                } else {
                    $replay->set('wn8.data.battle' => undef);
                }
                $brend->();
            });
        });
    }

    _generate_banner($self, $replay, $delay->begin(0));
    _misc($self, $replay, $delay->begin(0));
    _packetstore($self, $replay, $delay->begin(0));
    _ratings($self, $replay, $delay->begin(0));
}

sub get_vehicle_from_battleresult_by_accountid {
    my $self = shift;
    my $br   = shift;
    my $id   = shift;

    foreach my $k (keys(%{$br->{vehicles}})) {
        my $v = $br->{vehicles}->{$k};
        if($v->{accountDBID} + 0 == $id + 0) {
            $v->{vehicleID} = $k + 0;
            return $v;
        } 
    }
    return undef;
}

sub finalize_roster {
    my $self            = shift;
    my $replay          = shift;
    my $battle_result   = shift;
    my $roster          = $replay->get('roster');

    my $name_to_vidx = {};
    my $vid_to_vidx = {};
    my $i = 0;
    my $newroster = [];
    my $teams = [];
    my $plat  = {};
    my $pi    = 1;

    $self->debug('finalize_roster top');

    my $alternate_map = {};

    foreach my $entry (@$roster) {
        my $rawv = $self->get_vehicle_from_battleresult_by_accountid($battle_result => $entry->{accountDBID});

        if($entry->{prebattleID} > 0) {
            $plat->{$entry->{prebattleID}} = $pi++;
        }

        die 'unable to get vehicle from battleresult via account ID', "\n" unless(defined($rawv));

        $entry->{vehicleID} = $rawv->{vehicleID}; # this may break stuff

        $name_to_vidx->{$entry->{name}} = $i;
        $vid_to_vidx->{$entry->{vehicleID}} = $i;

        push(@{$teams->[$entry->{team} - 1]}, $i);

        my $newentry = {
            health  =>  {
                total       => ($rawv->{health} + $rawv->{damageReceived}),
                remaining   => $rawv->{health},
            },
            stats => { map { $_ => $rawv->{$_} } (qw/this damageAssistedTrack damageAssistedRadio he_hits pierced kills shots spotted tkills potentialDamageReceived noDamageShotsReceived credits mileage heHitsReceived hits damaged piercedReceived droppedCapturePoints damageReceived killerID damageDealt shotsReceived xp deathReason lifeTime tdamageDealt capturePoints achievements/) },
            player => $entry,
            platoon => (defined($plat->{$entry->{prebattleID}})) 
                ? $plat->{$entry->{prebattleID}} 
                : undef
        };

        if(my $v = $self->_vehicles->get(typecomp => $rawv->{typeCompDescr})) {
            $self->debug('Received vehicle from quickdb: ', Dumper($v));
            my $newvehicle = {};
            foreach my $key (keys(%$v)) {
                $newvehicle->{$key} = $v->{$key};
            }
            $newvehicle->{ident} = $v->{_id};
            $newvehicle->{id}    = $entry->{vehicleID};
            $newvehicle->{icon}  = sprintf('%s-%s.png', $v->{country}, $v->{name_lc});
            $newvehicle->{i18n}  = $v->{i18n};

            $newentry->{vehicle} = $newvehicle;
        }
        $newentry->{stats}->{isTeamKiller} = ($rawv->{isTeamKiller}) ? Mango::BSON::bson_true : Mango::BSON::bson_false;
        push(@$newroster, $newentry);
        $i++;
    }

    my $teams_sorted = {};
    my $roster_sorted = {};
    my $sort_key = { 
        damageDealt => 'damage',
        xp          => 'xp',
        kills       => 'kills',
    };

    foreach my $key (keys(%$sort_key)) {
        my $sk = $sort_key->{$key};

        $teams_sorted->{$sk} = [ [], [] ];

        foreach my $entry (sort { $b->{stats}->{$key} <=> $a->{stats}->{$key} } (@$newroster)) {
            push(@{$roster_sorted->{$sk}}, $vid_to_vidx->{$entry->{vehicle}->{id}});
            push(@{$teams_sorted->{$sk}->[$entry->{player}->{team} - 1]}, $entry->{vehicle}->{id});
        }
    }

    $replay->set('roster'           =>  $newroster);
    $replay->set('vehicles'         =>  $vid_to_vidx);
    $replay->set('players'          =>  $name_to_vidx);
    $replay->set('teams'            =>  $teams);
    $replay->set('roster_sorted'    =>  $roster_sorted);
    $replay->set('teams_sorted'     =>  $teams_sorted);

    $replay->set('game.recorder.vehicle' => {
        id      => $newroster->[ $name_to_vidx->{$replay->get('game.recorder.name')} ]->{vehicle}->{id},
        tier    => $newroster->[ $name_to_vidx->{$replay->get('game.recorder.name')} ]->{vehicle}->{level},
        ident   => $newroster->[ $name_to_vidx->{$replay->get('game.recorder.name')} ]->{vehicle}->{ident},
    });

    my $clan = $newroster->[ $name_to_vidx->{$replay->get('game.recorder.name')} ]->{player}->{clanAbbrev};
    $replay->set('game.recorder.clan' => (length($clan) > 0) ? $clan : undef);
}

sub stringify_awards {
    my $self = shift;
    my $res  = shift;
    my $a    = WR::Res::Achievements->new();
    my $t    = [];

    foreach my $item (@{$res->{stats}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $str);
    }
    return $t;
}

sub hashbucket {
    my $self = shift;
    my $str = shift;
    my $l = shift || 6;

    return join('/', (split(//, substr($str, 0, $l))));
}

sub generate_banner {
    my $self = shift;
    my $res  = shift;
    my $cb   = shift;
    my $image;
    my $recorder = $res->get('players')->{ $res->get('game.recorder.name') };

    unless(defined($self->banner_path)) {
        $self->warning('[generate_banner]: no banner path specified');
        $cb->({
            available => Mango::BSON::bson_false,
            error => 'No banner path specified',
        });
        return;
    }

    my $pv = $res->get('roster')->[ $recorder ]->{vehicle}->{ident};
    $pv =~ s/:/-/;

    my $xp = $res->get('stats.xp');
    $xp .= sprintf(' (x%d)', $res->get('stats.dailyXPFactor10')/10) if($res->get('stats.dailyXPFactor10') > 10);

    if(my $map = $self->_maps->get(numerical_id => $res->get('game.map'))) {
        my $match_result = ($res->get('game.winner') < 1) 
            ? 'draw'
            : ($res->get('game.winner') == $res->get('roster')->[ $recorder ]->{player}->{team})
                ? 'victory'
                : 'defeat';
                
        my $base_path = sprintf('%s/%s', $self->banner_path, $self->hashbucket($res->get('_id') . ''));
        make_path($base_path) unless(-e $base_path);

        my $i = WR::Provider::Imager->new();
        my $imagefile;

        my $tv = $self->_vehicles->get(_id => $res->get('roster')->[$recorder]->{vehicle}->{ident});
        my $vn = $tv->{label};

        my %imager_args = (
            map             => $map->{_id} . '',
            vehicle         => lc($pv),
            result          => $match_result,
            map_name        => $map->{label},
            vehicle_name    => $vn,
            credits         => $res->get('stats.credits') + 0,
            xp              => $xp,
            kills           => $res->get('stats.kills') + 0,
            spotted         => $res->get('stats.spotted') + 0,
            damaged         => $res->get('stats.damaged') + 0,
            player          => $res->get('roster')->[ $recorder ]->{player}->{name},
            clan            => ($res->get('roster')->[ $recorder ]->{player}->{clanDBID} > 0) ? $res->get('roster')->[ $recorder ]->{player}->{clanAbbrev} : undef,
            destination     => sprintf('%s/%s.jpg', $base_path, $res->get('_id') . ''),
            awards          => $self->stringify_awards($res),
        );

        $self->debug('[generate_banner]: generating banner using: ', Dumper({%imager_args}));

        try {
            $imagefile = $i->create(%imager_args);
            $image = {
                available => Mango::BSON::bson_true,
                file => $imagefile,
                url_path => sprintf('%s/%s.jpg', $self->hashbucket($res->get('_id') . ''), $res->get('_id') . ''),
            };
        } catch {
            my $e = $_;
            $image = {
                available => Mango::BSON::bson_false,
                error => $e,
                args  => { %imager_args }
            };
            $self->error('Creating image failed: ', $e);
        };
        $cb->($image);
    } else {
        $self->error('[generate_banner]: could not find map, disk paths set right? map: ', $res->get('game.map'));
        $cb->({
            available => Mango::BSON::bson_false,
            error => $_,
        });
    }
}


1;
