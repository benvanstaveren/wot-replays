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
use Beanstalk::Client;

$| = 1;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

my $mongo  = MongoDB::Connection->new();
my $bs = Beanstalk::Client->new({ server => 'localhost' });
$bs->watch('wot-replays');

sub getchat {
    my $id = shift;
    if(my $r = $mongo->get_database('wot-replays')->get_collection('replays')->find_one({ _id => $id })) {
        print '[replay]: found', "\n";
        print '[replay]: already', "\n" and return if($r->{chatProcessed});
        print '[replay]: processing', "\n";
        if(my $file = $mongo->get_database('wot-replays')->get_gridfs->find_one({ replay_id => $r->{_id} })) {
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

while(1) {
    my $job = $bs->reserve;
    my $id  = bless({ value => $job->data }, 'MongoDB::OID');
    print '[job]: received for ', $job->data, "\n";
    
    if(my $mj = $mongo->get_database('wot-replays')->get_collection('jobs')->find_one({ _id => $id })) {
        print '[job]: obtained', "\n";
        getchat($mj->{replay});
    }
    $bs->delete($job->id);
}

