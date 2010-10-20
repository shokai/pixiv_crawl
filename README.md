pixiv crawl
===========
get pixiv illusts


Dependencies
============
* mongodb


install gems
------------

    % sudo gem install bundler
    % bundle install



edit config.yaml
----------------

    % cp sample.config.yaml config.yaml

edit your pixiv account.


crawl
=====

crawl illust_id from 100000 to 110000

    % ruby crawl.rb 100000-110000
