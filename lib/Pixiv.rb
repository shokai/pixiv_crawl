# -*- coding: utf-8 -*-
require 'rubygems'
require 'open-uri'
require 'mechanize'
require 'nokogiri'
require 'kconv'

class Pixiv

  class Error < Exception
  end

  def initialize(user, pass)
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows IE 7'
    page = @agent.get('http://www.pixiv.net/')
    login_form = nil
    for form in page.forms do
      login_form = form if form.name == 'loginForm'
    end
    login_form.fields_with(:name => 'pixiv_id').first.value = user
    login_form.fields_with(:name => 'pass').first.value = pass
    page = login_form.click_button
    if page.uri.to_s != 'http://www.pixiv.net/mypage.php'
      throw 'login error'
    end
  end

  def get(url)
    res = @agent.get(url)
    doc = Nokogiri::HTML res.body.toutf8
    error = doc.xpath('//span[@class="error"]').first
    raise Error.new error.text if error
    res
  end

  # type='user'
  def get_bookmark_users(opts=nil)
    opts = [opts].flatten
    url = 'http://www.pixiv.net/bookmark.php?type=user'
    page = get(url)
    doc = Nokogiri::HTML(page.body.toutf8)
    p users = doc.xpath('//a').map{|a| "http://www.pixiv.net/#{a['href']}"}.delete_if{|href|
      !(href =~ /http:\/\/www\.pixiv.net\/member\.php\?id=\d+/)
    }
    users_size = doc.xpath('//h3').map{|h|h.text}.delete_if{|h| !(h=~/お気に入りユーザー/)}.first.to_s.scan(/(\d+)/).first.first.to_i
    if opts.index(:all)
      for i in 2..(users_size/20+1) do
        sleep 5
        next_page = get("#{url}&p=#{i}")
        next_doc = Nokogiri::HTML(next_page.body.toutf8)
        users << next_doc.xpath('//a').map{|a| "http://www.pixiv.net/#{a['href']}"}.delete_if{|href|
          !(href =~ /http:\/\/www\.pixiv.net\/member\.php\?id=\d+/)
        }
      end
      users.flatten!
    end

    {
      :users => users,
      :users_size => users_size
    }

  end

  # opt = :all で全ページ取得
  def get_user(url_or_id, opts=nil)
    opts = [opts].flatten
    if url_or_id.to_s =~ /^\d+$/
      id = url_or_id.to_i
    else
      id = url_or_id.to_s.scan(/id=(\d+)/).first.first.to_i
    end
    url = "http://www.pixiv.net/member_illust.php?id=#{id}"
    page = get(url)
    doc = Nokogiri::HTML(page.body.toutf8)
    title = doc.xpath('//title').first.content
    name = title.scan(/^「(.*)」のイラスト/).first.first
    illusts_size = doc.xpath('//h3/span').map{|s|s.text}.delete_if{|s|!(s=~/\d+件/)}.first.scan(/(\d+)件/).first.first.to_i
    illusts = doc.xpath('//a').map{|a| "http://www.pixiv.net/#{a['href']}"}.delete_if{|href|
      !(href =~ /http:\/\/www\.pixiv\.net\/member_illust.php\?.*illust_id=\d+/)
    }
    if opts.index(:all) and illusts_size > 20
      for i in 2..(illusts_size/20+1) do
        sleep 5
        next_page = get("#{url}&p=#{i}")
        next_doc = Nokogiri::HTML(next_page.body.toutf8)
        illusts << next_doc.xpath('//a').map{|a|
          "http://www.pixiv.net/#{a['href']}"}.delete_if{|href|
          !(href =~ /http:\/\/www\.pixiv\.net\/member_illust.php\?.*illust_id=\d+/)
        }
      end
      illusts.flatten!
    end

    {
      :url => url,
      :id => id,
      :title => title,
      :name => name,
      :illusts => illusts,
      :illusts_size => illusts_size
    }
  end

  def get_illust(url_or_id)
    if url_or_id.to_s =~ /^\d+$/
      url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{url_or_id}"
      id = url_or_id.to_i
    else
      url = url_or_id.to_s
      id = url_or_id.scan(/illust_id=(\d+)/).first.first.to_i
    end
    begin
      page = get(url)
    rescue => e
      raise e
    end
    doc = Nokogiri::HTML(page.body.toutf8)
    
    title = doc.xpath('//title').first.content
    description = doc.xpath('//div[@class="works_area"]/p').first.text rescue description = nil
    tags = doc.xpath('//span[@id="tags"]//a').map{|a|
      a.content
    }.delete_if{|tag| tag.to_s.size < 1 } rescue tags = []
    begin
    works_data = doc.xpath('//div[@class="works_data"]/p').first.text
    rescue
      raise Error.new 'illust get error'
    end
    date = works_data.scan(/(\d+年\d+月\d+日 \d+:\d+)/).first.first
    date = Time.gm(date.scan(/(\d+)年/).first.first.to_i,
                   date.scan(/(\d+)月/).first.first.to_i,
                   date.scan(/(\d+)日/).first.first.to_i,
                   date.scan(/(\d+):/).first.first.to_i,
                   date.scan(/:(\d+)/).first.first.to_i)
    
    size_tmp = works_data.scan(/(\d+×\d+)/).first.first
    if size_tmp
      size = {
        :width => size_tmp.scan(/(\d+)×\d+/).first.first.to_i,
        :height => size_tmp.scan(/\d+×(\d+)/).first.first.to_i
      }
    end

    begin
      score = doc.xpath('//div[@id="unit"]/h4').text.scan(/閲覧数：(\d+)　評価回数：(\d+)　総合点：(\d+)/).first
    rescue
      raise Error.new 'illust get error'
    end
    score = {
      :pageview => score[0].to_i,
      :rated => score[1].to_i,
      :total => score[2].to_i
    }

    scroll = doc.xpath('//a').map{|a| a['href']}.delete_if{|href|
      !(href =~ /type=scroll/)
    }.first
    if scroll
      sleep 5
      scroll_page = get("http://www.pixiv.net/#{scroll}")
      scroll_doc = Nokogiri::HTML(scroll_page.body.toutf8)
      imgs = scroll_doc.xpath('//img').map{|img|img['src'] }.delete_if{|src|
        !(src =~ /^http:\/\/img\d+\.pixiv.net\/img\/.+\/\d+.+$/)
      }
      user = imgs.first.scan(/^http:\/\/img\d+\.pixiv.net\/img\/(.+)\/\d+.+$/).first.first
    else
      img_m = doc.xpath('//img').map{|img| img['src']}.delete_if{|src|
        !(src =~ /^http:\/\/img\d+\.pixiv.net\/img\/.+\/\d+.+$/)
      }.first
      img = img_m.scan(/(^http:\/\/img\d+\.pixiv.net\/img\/.+\/\d+)_m(.+)$/).first.join('')
      user = img_m.scan(/^http:\/\/img\d+\.pixiv.net\/img\/(.+)\/\d+.+$/).first.first
    end
    
    result = {
      :title => title,
      :description => description,
      :date => date.to_i,
      :score => score,
      :tags => tags,
      :user => user,
      :url => url,
      :illust_id => id,
      :size => size
    }
    if scroll
      result[:imgs] = imgs
    else
      result[:img] = img
      result[:img_m] = img_m
    end
    result
  end
end
