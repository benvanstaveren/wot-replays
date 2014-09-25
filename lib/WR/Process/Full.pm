package WR::Process::Full;
use Mojo::Base 'WR::Process::Base';
use WR::Parser;
use WR::Res::Achievements;
use WR::Provider::ServerFinder;
use WR::Provider::Imager;
use WR::Provider::Panelator;
use WR::Util::HashTable;
use WR::Constants qw/nation_id_to_name decode_arena_type_id ARENA_PERIOD_BATTLE gameplay_id_to_name/;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use WR::Util::QuickDB;
use WR::PrivacyManager;
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
    return Mango->new($self->config->get('mongodb.host'));
};
    
has 'banner_path'   => sub { return shift->config->get('paths.banners') };
has 'packet_path'   => sub { return shift->config->get('paths.packets') };
has 'banner'        => 1;

has 'packets'       => sub { [] };
has 'ua'            => sub { Mojo::UserAgent->new };

has '_existing'     => undef;

has [qw/_components _consumables _maps _vehicles/] => undef;

has 'push'          => sub {
    my $self = shift;
    return WR::Thunderpush::Server->new(host => 'push.wotreplays.org', secret => $self->config->get('thunderpush.secret'), key => $self->config->get('thunderpush.key'));
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
            $self->$attr(WR::Util::QuickDB->new(data => $d));
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
            $self->job->set_error('Process error: ', $e => sub {
                $self->error('Process error: ', $e);
                $cb->($self, $e, undef);
            });
        };
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
                $self->emit('state.streaming.progress' => { count => $v });
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

            $replay->set('game.battle_level'    => (defined($init->{battle_level})) ? $init->{battle_level} + 0 : undef);
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
        $game->on('arena.vehicle_list' => sub {
            my ($g, $v) = (@_);

            $replay->set('roster' => $v->{list});
        });
        $game->on(finish => sub {
            my ($game, $reason) = (@_);
            $self->debug('$game->on finish callback');
            $self->emit('state.streaming.finish' => { total => $game->stream->len });
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
        $self->emit('state.streaming.start' => { total => $game->stream->len });
        $self->debug('pre $game->start');
        $game->start;
        $self->debug('post $game->start');
    } else {
        return $cb->(undef, 'Could not stream replay');
    }
}

sub _setup_legacy_state_handlers {
    my $self = shift;

    $self->on('state.prepare.start' => sub {
        $self->debug('state.prepare.start');
        $self->job->set_status({
            id      =>  'prepare',
            text    =>  'Preparing replay...',
            i18n    =>  'process.state.prepare',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        } => sub {
        });
            
    });
    $self->on('state.prepare.finish' => sub {
        $self->debug('state.prepare.finish');
        $self->job->set_status({
            id      =>  'prepare',
            done    =>  Mango::BSON::bson_true,
        } => sub {
        });
    });
    $self->on('state.streaming.start' => sub {
        my ($o, $t) = (@_);
        $self->debug('state.streaming.start');
        $self->job->set_status({
            id      =>  'streaming',
            text    =>  'Streaming packets',
            i18n    =>  'process.state.streaming',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        } => sub {
        });
    });
    $self->on('state.streaming.finish' => sub {
        my ($o, $t) = (@_);
        $self->debug('state.streaming.finish');
        $self->job->set_status({
            id      =>  'streaming',
            done    =>  Mango::BSON::bson_true
        } => sub {
        });
    });
    $self->on('state.generatebanner.start' => sub {
        $self->debug('state.generatebanner.start');
        $self->job->set_status({
            id      =>  'generatebanner',
            text    =>  'Generating banner...',
            i18n    =>  'process.state.generatebanner',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        } => sub {
        });
    });
    $self->on('state.generatebanner.finish' => sub {
        $self->debug('state.generatebanner.finish');
        $self->job->set_status({
            id      =>  'generatebanner',
            done    =>  Mango::BSON::bson_true,
        } => sub {
        });
    });
    $self->on('state.packet.save.start' => sub {
        $self->debug('state.packet.save.start');
        $self->job->set_status({
            id      =>  'packetsave',
            text    =>  'Saving packets to disk...',
            i18n    =>  'process.state.packetsave',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        } => sub {
        });
    });
    $self->on('state.packet.save.finish' => sub {
        $self->debug('state.packet.save.finish');
        $self->job->set_status({
            id      =>  'packetsave',
            done    =>  Mango::BSON::bson_true,
        } => sub {
        });
    });
    $self->on('state.wn7.start' => sub {
        my ($o, $t) = (@_);
        $self->debug('state.wn7.start');
        $self->job->set_status({
            id      =>  'wn7',
            text    =>  'Fetching ratings from Statterbox',
            i18n    =>  'process.state.rating',
            type    =>  'spinner',
            done    =>  Mango::BSON::bson_false,
        } => sub {
        });
    });
    $self->on('state.wn7.finish' => sub {
        my ($o, $t) = (@_);
        $self->debug('state.wn7.finish');
        $self->job->set_status({
            id      =>  'wn7',
            done    =>  Mango::BSON::bson_true,
        } => sub {
        });
    });
}

sub _fix_replay_junk {
    my $self = shift;
    my $replay = shift;

    if($replay->get('game.winner') == 0) {
        $replay->set('game.victory' => -1); # draw
    } else {
        $replay->set('game.victory' => ($replay->get('game.winner') == $replay->get('game.recorder.team')) ? 1 : 0);
    }
    $replay->set('stats.damageAssisted' => $replay->get('stats.damageAssistedTrack') + $replay->get('stats.damageAssistedRadio'));


    # create the cids - 
    my $cid = {
        player      => sprintf('%s-%s', lc($replay->get('game.server')), lc($replay->get('game.recorder.name'))),
        clan        => undef,
        involved    => {
            player  =>  [],
            clan    =>  [],
            team    =>  [],
        },
    };

    if(defined($replay->get('game.recorder.clan'))) {
        $cid->{clan} = sprintf('%s-%s', lc($replay->get('game.server')), lc($replay->get('game.recorder.clan')));
    } 

    my $i = $replay->get('involved');

    foreach my $p (@{$i->{players}}) {
        push(@{$cid->{involved}->{player}}, sprintf('%s-%s', lc($replay->get('game.server')), lc($p)));
    }
    foreach my $p (@{$i->{clans}}) {
        push(@{$cid->{involved}->{clan}}, sprintf('%s-%s', lc($replay->get('game.server')), lc($p)));
    }
    foreach my $p (@{$i->{team}}) {
        push(@{$cid->{involved}->{team}}, sprintf('%s-%s', lc($replay->get('game.server')), lc($p)));
    }

    $replay->set('cid' => $cid);
}

sub _with_battle_result {
    my $self    = shift;
    my $parser  = shift;
    my $replay  = shift;
    my $br      = shift;
    my $cb      = shift;

    $self->process_battle_result($replay, $br, sub {
        if(my $replay = shift) {
            $self->debug('process_battleresult returned replay');

            # fix up the replay with some additional junk
            $self->_fix_replay_junk($replay);

            # this really oughta move into the stream events
            if($replay->get('game.version_numeric') < $self->config->get('wot.min_version')) {
                $self->job->unlink;
                $self->job->set_error('That replay is from an older version of World of Tanks which we cannot process...' => sub {
                    return $cb->($self, undef, 'That replay is from an older version of World of tanks which we cannot process...');
                });
            } elsif($replay->get('game.version_numeric') > $self->config->get('wot.version_numeric')) {
                $self->job->unlink;
                $self->job->set_error('That replay is from a newer version of World of Tanks which we cannot process...' => sub {
                    return $cb->($self, undef, 'That replay is from a newer version of World of tanks which we cannot process...');
                });
            } else {
                $replay->set('digest' => $self->job->_id);
                $replay->set('file' => $self->job->data->{file_base});

                # see if a replay like this already exists
                my $query = {
                    'game.server'           =>  $replay->get('game.server'),
                    'game.recorder.name'    =>  $replay->get('game.recorder.name'),
                    'game.arena_id'         =>  $replay->get('game.arena_id')
                };

                $self->model('wot-replays.replays')->find_one($query => sub {
                    my ($coll, $err, $doc) = (@_);
                    if(defined($doc)) {
                        $self->debug('*** REPLAY WITH SAME SERVER, RECORDER AND ARENA ID ALREADY EXISTS');
                        $self->debug('     OLD ID: ', $replay->get('_id'), ' NEW ID: ', $doc->{_id});
                        $replay->set('_id' => $doc->{_id});
                        $replay->set('site' => $doc->{site});
                        $replay->set('site.orphan' => Mango::BSON::bson_false);

                        # hashtable delete is not reliable so, do it like this. Need to clear the orphan table in order for this to
                        # work reliably
                        delete($replay->data->{site}->{minimal});
                    } else {
                        $replay->set('site.visible' => ($self->job->data->{visible} < 1) ? Mango::BSON::bson_false : Mango::BSON::bson_true);
                        if($self->job->data->{privacy} == -1) {
                            $self->debug('Privacy set to default, adjusting');
                            my $bonus_type = $replay->get('game.bonus_type');
                            if($bonus_type == 1) { # random
                                $replay->set('site.visible' => Mango::BSON::bson_true);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_PUBLIC);
                                $self->debug('privacy: public');
                            } elsif($bonus_type == 2) { # training
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_PARTICIPANTS);
                                $self->debug('privacy: participants');
                            } elsif($bonus_type == 3) { # company
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_TEAM);
                                $self->debug('privacy: team');
                            } elsif($bonus_type == 4) { # tournament
                                $replay->set('site.visible' => Mango::BSON::bson_true);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_PUBLIC);
                                $self->debug('privacy: public');
                            } elsif($bonus_type == 5) { # clan
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_CLAN);
                                $self->debug('privacy: clan');
                            } elsif($bonus_type == 6) { # tutorial
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_PRIVATE);
                                $self->debug('privacy: private');
                            } elsif($bonus_type == 7) { # cybersport
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_TEAM);
                                $self->debug('privacy: team');
                            } else {
                                $replay->set('site.visible' => Mango::BSON::bson_true);
                                $replay->set('site.privacy' => WR::PrivacyManager->PRIVACY_PUBLIC);
                                $self->debug('privacy: public');
                            }
                        } else {
                            $self->debug('preselected privacy');
                            if($self->job->data->{privacy} > 0) {
                                $replay->set('site.visible' => Mango::BSON::bson_false);
                            } else {
                                $replay->set('site.visible' => Mango::BSON::bson_true);
                            }
                            $replay->set('site.privacy' => $self->job->data->{privacy} || 0);
                        }
                        $replay->set('site.description' => (defined($self->job->data->{desc}) && length($self->job->data->{desc}) > 0) ? $self->job->data->{desc} : undef);
                        $replay->set('site.uploaded_at' => Mango::BSON::bson_time());
                    }

                    # create the panel - we'll switch to using data mode here
                    my $data = $replay->data;

                    WR::Provider::Panelator->new(db => $self->mango->db('wot-replays'))->panelate($data => sub {
                        $data->{panel} = shift;
                        
                        $self->model('wot-replays.replays')->save($data => sub {
                            my ($c, $e, $d) = (@_);

                            if(defined($e)) {
                                $self->error('full store fail: ', $e);
                                $self->job->set_error('store fail: ', $e => sub {
                                    return $cb->($self, undef, $e);
                                });
                            } else {
                                $self->debug('full replay saved ok');
                                $self->job->set_complete($replay => sub {
                                    $self->push->send_to_channel('site' => Mojo::JSON->new->encode({ evt => 'replay.processed',  data => { url => sprintf('/replay/%s.html', $data->{_id} . '') }}) => sub {
                                        $self->debug('full job complete cb');
                                        return $cb->($self, $replay, undef);
                                    });
                                });
                            }
                        });
                    });
                });
            }
        } else {
            # assume the job's been set to te proper status already
            $self->debug('process_battleresult returned undef');
            return $cb->($self, undef, 'process_battleresult error');
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
            WR::Provider::Panelator->new(db => $self->mango->db('wot-replays'))->panelate($data => sub {
                $data->{panel} = shift;
                $self->model('wot-replays.replays')->save($data => sub {
                    my ($c, $e, $d) = (@_);

                    if(defined($e)) {
                        $self->error('minimal store fail: ', $e);
                        $self->job->set_error('minimal store fail: ', $e => sub {
                            return $cb->($self, undef, $e);
                        });
                    } else {
                        $self->debug('minimal replay saved ok');
                        $self->job->set_complete($replay => sub {
                            $self->debug('minimal job complete cb');
                            return $cb->($self, $replay, undef);
                        });
                    }
                });
            });
        }
    });
}

sub _real_process {
    my $self   = shift;
    my $parser = shift;
    my $cb     = shift;

    my $replay = WR::Util::HashTable->new(data => {});
    if(defined($self->job->replayid)) {
        $self->debug('job has existing replayid');
        $replay->set('_id' => $self->job->replayid); # we're re-doing an existing replay
        $replay->set('site.orphan' => Mango::BSON::bson_true); # not entirely true, but we might as well abuse the flag for it
    } else {
        $self->debug('job for potentially new replay');
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
            $self->job->set_error($error => sub {
                $self->error($error);
                $cb->($self, undef, $error);
            });
        } else {
            # figure out if the replay has a battle result, if it doesn't, just store
            # it as a minimal replay
            if($parser->has_battle_result) {
                $self->debug('replay has battle result');
                $self->_with_battle_result($parser, $replay, $parser->get_battle_result, $cb);
            } else {
                $self->debug('replay has no battle result, attempting lookup using [', $replay->get('game.arena_id') . '', ']');
                # see if we happen to have an uploaded battle result for this replay
                my $arena_id = $replay->get('game.arena_id') . '';

                $self->model('wot-replays.battleresults')->find_one({
                    'arena_id'                           => $arena_id . '',
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
    $replay->set('digest'           => $self->job->_id);
    $replay->set('site.minimal'     => Mango::BSON::bson_true);
    $replay->set('site.visible'     => Mango::BSON::bson_false);
    $replay->set('site.privacy'     => 1); # unlisted
    $replay->set('game.server'      => WR::Provider::ServerFinder->new->get_server_by_id($replay->get('game.recorder.account_id')));
    $replay->set('site.uploaded_at' => Mango::BSON::bson_time);

    $replay->set('game.started'     => Mango::BSON::bson_time( ($replay->get('game.arena_id') & 4294967295) * 1000 ));

    $self->debug('process minimal complete, replay data now: ', Dumper($replay->data));

    $cb->($replay);
}

sub p_br_generate_banner {
    my $self = shift;
    my $replay = shift;

    $self->emit('state.generatebanner.start' => {});
    $self->debug('preparing banner');
    $self->generate_banner($replay => sub {
        my $image = shift;
        $self->emit('state.generatebanner.finish' => {});
        $replay->set('site.banner' => $image);
    });
}

sub p_br_packetstore {
    my $self = shift;
    my $replay = shift;

    $self->debug('storing packets for replay');
    $self->emit('state.packet.save.start' => {});
    my $base_path = sprintf('%s/%s', $self->packet_path, $self->hashbucket($replay->get('_id') . '', 7));
    make_path($base_path) unless(-e $base_path);
    my $packet_file = sprintf('%s/%s.json', $base_path, $replay->get('_id') . '');
    if(my $fh = IO::File->new(sprintf('>%s', $packet_file))) {
        my $json = Mojo::JSON->new();
        $fh->print($json->encode($self->packets));
        $fh->close;
        $self->debug('wrote packets to file');
        $replay->set('packets' => sprintf('%s/%s.json', $self->hashbucket($replay->get('_id') . '', 7), $replay->get('_id') . ''));
        $self->emit('state.packet.save.finish' => {});
    } else {
        $self->debug('could not write packets to file');
        $replay->set('packets' => undef);
        $self->emit('state.packet.save.finish' => {});
    }
}

sub p_br_misc {
    my $self = shift;
    my $replay = shift;

    $replay->set('game.server'          => WR::Provider::ServerFinder->new->get_server_by_id($replay->get('game.recorder.account_id')));
    $replay->set('game.recorder.index'  => $replay->get('players')->{$replay->get('game.recorder.name')});

    my $tc = {};
    my $pt = [];
    foreach my $entry (@{$replay->get('roster')}) {
        push(@$pt, $entry->{player}->{name}) if($entry->{player}->{team} == $replay->get('game.recorder.team'));
        next unless(length($entry->{player}->{clanAbbrev}) > 0);
        $tc->{$entry->{player}->{clanAbbrev}}++;
    }

    $replay->set('involved' => {
        players     => [ keys(%{$replay->get('players')}) ],
        clans       => [ keys(%$tc) ],
        vehicles    => [ map { $_->{vehicle}->{ident} } @{$replay->get('roster')} ],
        team        => $pt,
    });
}

sub _wn8_all {
    my $self   = shift;
    my $replay = shift;

    my $roster     = $replay->get('roster');
    my $phash      = { map { $_->{player}->{accountDBID} => 1 } @$roster };

    delete($phash->{$replay->get('game.recorder.account_id')});

    my $account_id = join(',', (keys(%$phash)));

    $self->debug('[WN8:ALL]: getting wn8 for all players except recorder');
    if(my $tx = $self->ua->post('http://api.statterbox.com/wot/account/wn8' => form => {
        application_id  => $self->config->get('statterbox.server'),
        account_id      => $account_id,
        cluster         => $self->fix_server($replay->get('game.server')),
    })) {
        if(my $res = $tx->success) {
            if($res->json('/status') eq 'ok') {
                $self->debug('[WN8:ALL] wn8 status ok');
                my $data = $res->json('/data');
                # unfortunately we now need to map each player ID to an entry in the roster 
                $self->debug('[WN8:ALL] wn8 response: ', Dumper($data));
                foreach my $id (keys(%$data)) {
                    if(my $entry = $self->roster_entry_by_account_id($roster, $id)) {
                        if(defined($data->{$id}) && ref($data->{$id}) eq 'HASH') {
                            if(defined($data->{$id}->{wn8})) {
                                $self->debug('[WN8:ALL] have roster entry for ', $id, ' wn8 is ', $data->{$id}->{wn8});
                            } else {
                                $self->debug('[WN8:ALL] have roster entry for ', $id, 'no wn8 calculated');
                            }
                            $entry->{wn8} = { 
                                available => Mango::BSON::bson_true,
                                data => { overall => $data->{$id}->{wn8} }
                            };
                        } else {
                            $self->debug('[WN8:ALL] have roster entry for ', $id, ' but no wn8 data');
                            $entry->{wn8} = { 
                                available => Mango::BSON::bson_false,
                                data => { overall => 0 }
                            };
                        }
                    } else {
                        $self->error('[WN8:ALL] no roster entry for ', $id);
                    }
                }
            } else {
                $self->debug('[WN8:ALL] wn8 status not ok', Dumper($res->json('/error')));
            }
        } else {
            my ($err, $code) = $tx->error;
            $self->debug('[WN8:ALL] wn8 res not success, code: ', $code, ' err: ', $err);
        }
    } else {
        $self->debug('[WN8:ALL] no tx');
    }
}

sub _wn8_recorder {
    my $self = shift;
    my $replay = shift;

    $self->debug('[WN8.RECORDER]: getting wn8 for recorder');
    if(my $tx = $self->ua->post('http://api.statterbox.com/wot/account/wn8' => form => {
        application_id  => $self->config->get('statterbox.server'),
        account_id      => $replay->get('game.recorder.account_id'),
        cluster         => $self->fix_server($replay->get('game.server')),
    })) {
        if(my $res = $tx->success) {
            if($res->json('/status') eq 'ok') {
                $replay->set('wn8.available' => Mango::BSON::bson_true);
                $replay->set('wn8.data.overall' => $res->json('/data')->{$replay->get('game.recorder.account_id')}->{wn8});
                $self->debug('[WN8.RECORDER]: wn8 for recorder callback, wn8 set to: ', $replay->get('wn8.data.overall'));
            } else {
                $replay->set('wn8.available' => Mango::BSON::bson_false);
                $replay->set('wn8.data.overall' => undef);
                $self->debug('[WN8.RECORDER]: wn8 for player callback, status not ok');
            }
            my $idx    = $replay->get('players')->{$replay->get('game.recorder.name')};
            my $roster = $replay->at('roster' => $idx);
            $roster->{wn8} = {
                available => $replay->get('wn8.available'),
                data => {
                    overall => $replay->get('wn8.data.overall')
                }
            };
        } else {
            $replay->set('wn8.available' => Mango::BSON::bson_false);
            $replay->set('wn8.data.overall' => undef);
            $self->debug('[WN8.RECORDER]: wn8 for player callback, tx not ok');
        }
    } else {
        $self->debug('[WN8.RECORDER]: no tx');
    }
}

sub _wn8_battle {
    my $self = shift;
    my $replay = shift;

    $self->debug('[WN8.BATTLE]: getting wn8 for battle');
    my $entry = $replay->get('roster')->[ $replay->get('players')->{$replay->get('game.recorder.name')} ];
    my $battle_url = sprintf('http://api.statterbox.com/util/calc/wn8?application_id=%s&t=%d&frags=%d&damage=%d&spots=%d&defense=%d',
        $self->config->get('statterbox.server'),
        $entry->{vehicle}->{typecomp},
        $replay->get('stats.kills') + 0,
        $replay->get('stats.damageDealt') + 0,
        $replay->get('stats.spotted') + 0,
        $replay->get('stats.droppedCapturePoints') + 0
        );

    $self->debug(sprintf('[WN8.BATTLE]: Getting battle WN8 from: %s', $battle_url));
    if(my $tx = $self->ua->get($battle_url)) {
        if(my $res = $tx->success) {
            $replay->set('wn8.data.battle' => $res->json('/wn8'));
            $self->debug('[WN8.BATTLE]: wn8 battle callback, ok');
        } else {
            $replay->set('wn8.data.battle' => undef);
            $self->debug('[WN8.BATTLE]: wn8 battle callback, not ok');
        }
    } else {
        $self->debug('[WN8.BATTLE]: no tx');
    }
}

sub p_br_ratings {
    my $self   = shift;
    my $replay = shift;

    $self->debug('p_br_ratings top');

    $self->emit('state.wn7.start' => {});

    $self->ua->inactivity_timeout(120);
    $self->_wn8_battle($replay);
    $self->_wn8_recorder($replay);

    $self->ua->inactivity_timeout(300);
    $self->_wn8_all($replay);

    $self->emit('state.wn7.finish' => {});

    $self->debug('p_br_ratings bottom');
}

sub process_battle_result {
    my $self          = shift;
    my $replay        = shift;
    my $battle_result = shift;
    my $cb            = shift;
    my $e             = undef;

    try {
        $self->finalize_roster($replay, $battle_result);
    } catch {
        $e = $_;
    };

    if(defined($e)) {
        $self->job->set_error('finalize_roster: ', $e => sub {
            $self->error('finalize_roster: ', $e);
            return $cb->(undef); # this potentially may go really wrong
        });
        return undef;
    }

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

    $self->p_br_misc($replay);
    $self->p_br_generate_banner($replay);
    $self->p_br_packetstore($replay);
    $self->p_br_ratings($replay);

    $self->debug('process_battle_result bottom');

    return $cb->($replay);
}

sub roster_entry_by_account_id {
    my $self   = shift;
    my $roster = shift;
    my $id     = shift;

    foreach my $e (@$roster) {
        return $e if($e->{player}->{accountDBID} + 0 == $id + 0);
    }
    return undef;
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
        return $cb->({
            available => Mango::BSON::bson_false,
            error => 'No banner path specified',
        });
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
        return $cb->($image);
    } else {
        $self->error('[generate_banner]: could not find map, disk paths set right? map: ', $res->get('game.map'));
        return $cb->({
            available => Mango::BSON::bson_false,
            error => $_,
        });
    }
}


1;
