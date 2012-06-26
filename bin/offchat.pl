#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use WR;
use WR::Parser;
use boolean;
use MongoDB;
use Try::Tiny;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new();

sub getchat {
    my $id = shift;
    if(my $r = $mongo->get_database('wot-replays')->get_collection('replays')->find_one({ _id => $id })) {
        print '[replay]: found', "\n";
        print '[replay]: already', "\n" and return if($r->{chatProcessed});
        print '[replay]: processing', "\n";
        if(my $file = $mongo->get_database('wot-replays')->get_gridfs->find_one({ replay_id => $r->{_id} })) {
            print '[replay]: got file', "\n";
            my $parser = WR::Parser->new(
                bf_key => WOT_BF_KEY,
                traits => [qw/
                    LL::Memory
                    Data::Reader
                    Data::Decrypt
                    Data::Attributes
                    Data::Chat
                    /],
                data => $file->slurp,
            );
            print '[replay]: parser ready', "\n";
            my $messages;
            my $e;
            try {
                $messages = $parser->chat_messages;
            } catch {
                $e = $_;
            };
            if($e) {
                print 'ERROR: ', $e, "\n";
                return;
            }
            my $seq = 0;
            foreach my $message (@$messages) {
                $mongo->get_database('wot-replays')->get_collection('replays.chat')->save({
                    version     =>  $parser->wot_version,
                    replay_id   =>  $r->{_id},
                    sequence    =>  $seq++,
                    source      =>  $message->{source},
                    channel     =>  $message->{channel},
                    body        =>  $message->{body},
                });
            }
            $mongo->get_database('wot-replays')->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { chatProcessed => true } });
            print 'DONE', "\n";
        } else {
            print '[replay]: no file', "\n";
        }
    }
}

my $cursor = $mongo->get_database('wot-replays')->get_collection('replays')->find({ chatProcessed => false })->sort({ 'site.uploaded_at' => 1 });
while(my $r = $cursor->next()) {
    try {
        getchat($r->{_id});
    } catch {
        print '[replay]: error getting chat: ', $_, "\n";
    };
}
