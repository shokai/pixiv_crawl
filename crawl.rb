# -*- coding: utf-8 -*-
require 'rubygems'
require File.dirname(__FILE__)+'/helper'
require 'open-uri'
require 'pp'
$KCODE = 'u'

arg = ARGV.first
unless arg =~ /\d+-\d+/
  STDERR.puts "ruby crawl.rb 1-1000"
  exit 1
end
first, last = arg.scan(/(\d+)-(\d+)/).first.map{|i|i.to_i}
puts "crawl #{first} ... #{last}"

begin
  pix = Pixiv.new(@conf['pixiv_user'], @conf['pixiv_pass'])
  puts 'pixiv login'
rescue
  STDERR.puts 'pixiv login error'
  exit 1
end

error_count = 0
for id in first..last
  puts "--- #{id}"
  if error_count > 10
    STDERR.puts "error_count : #{error_count}"
    exit 1
  end
  next if @db['imgs'].find({:illust_id => id}).count > 0
  begin
    illust = pix.get_illust(id)
  rescue Pixiv::Error => e
    STDERR.puts e
    @db['imgs'].insert({:illust_id => id, :error => e.to_s, :stored_at => Time.now.to_i})
    sleep @conf['sleep']
    next
  rescue Timeout::Error => e
    STDERR.puts e
    error_count += 1
    sleep @conf['sleep']
    next
  rescue => e
    STDERR.puts e
    error_count += 1
    sleep @conf['sleep']
    next
  end

  img_urls = [illust[:img]] if illust[:img]
  img_urls = illust[:imgs] if illust[:imgs]
  for url in img_urls do
    filename = url.gsub(/https?:\/\//,'').gsub(/\//, '_')
    Dir.mkdir(@datadir) unless File.exists?(@datadir)
    begin
      open(url, 'Referer' => illust[:url]){|img_data|
        open("#{@datadir}/#{filename}", 'w+').write img_data.read
      }
    rescue Timeout::Error => e
      STDERR.puts e
      error_count += 1
      sleep @conf['sleep']
      next
    rescue => e
      STDERR.puts e
      error_count += 1
      sleep @conf['sleep']
      next
    end
    unless File::stat("#{@datadir}/#{filename}").size > 0
      error_count += 1
    else
      illust[:filename] = filename
      illust[:stored_at] = Time.now.to_i
      @db['imgs'].insert illust
      pp illust
      puts "--- #{id} stored!"
      error_count = 0
    end
    sleep @conf['sleep']
  end

end
