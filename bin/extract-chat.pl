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
my $db     = $mongo->get_database('wot-replays');
my $gfs    = $db->get_gridfs;
my $rc     = $db->get_collection('replays')->find()->sort({ 'site.uploaded_at' => -1 });
my $mc     = $db->get_collection('replays.chat');

while(my $r = $rc->next()) {
    next if($r->{chatProcessed});
    if(my $file = $gfs->find_one({ replay_id => $r->{_id} })) {
        print $r->{_id}, ': ';
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

        my $messages;
        my $e;
        try {
            $messages = $parser->chat_messages;
        } catch {
            $e = $_;
        };

        if($e) {
            print 'ERROR', "\n";
        } else {
            my $seq = 0;
            foreach my $message (@$messages) {
                $mc->save({
                    replay_id   =>  $r->{_id},
                    sequence    =>  $seq++,
                    source      =>  $message->{source},
                    channel     =>  $message->{channel},
                    body        =>  $message->{body},
                });
            }
            $db->get_collection('replays')->update({ _id => $r->{_id} }, { '$set' => { chatProcessed => true } });
            print 'DONE', "\n";
        }
    }
}
