wot-replays
===========

The code powering wot-replays.org

Contributing
------------

You're more than welcome to contribute to the site's code; keep in mind that it is a rather clunky affair due to the legacy code present, but don't let that stop you.

Prerequisites
-------------

You need to have the following installed and running in order to even run the site code locally:

    * MongoDB
    * Perl
    
Perl module wise:

    * Mojolicious
    * Mango
    * Mojolicious::Plugin::TtRenderer
    * Mojolicious::Plugin::Config
    * Crypt::Blowfish
    * IO::Uncompress::AnyUncompress
    * Try::Tiny
    
Blowfish Key
------------

The blowfish key is required for decrypting replays, if you want it you'll have to PM me for it since I don't want to invoke the ire of WG by sticking it online for everyone to see.
