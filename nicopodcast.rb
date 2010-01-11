# -*- coding: utf-8 -*-


require 'rubygems'
require 'sinatra'
require 'rss'
require 'nicovideo'

get '/nicopodcast/feed/:mylistid' do
  in_feed = download_feed "http://www.nicovideo.jp/mylist/#{params[:mylistid]}?rss=2.0"

  url = URI.parse(request.url)
  if url.port == 80
    baseurl = "#{url.scheme}://#{url.host}/"
  else 
    baseurl = "#{url.scheme}://#{url.host}:#{url.port}"
  end

  out_feed = generate_feed in_feed,baseurl
  out_feed.to_s
end

get '/nicopodcast/content/*.mp4' do
  movieid = params[:splat].first
  content_type :mp4
  begin
    tempdir = "/tmp"
    flv = Tempfile.open("#{movieid}.flv",tempdir)

    download(movieid,"#{ENV['HOME']}/.nicovideo/account.yml",flv)

    mp4 = File.open("#{tempdir}/#{movieid}.mp4",'w')
    encode flv,mp4
    send_file mp4.path

    flv.close
  rescue =>err
    p err
    status 404
  end
end

def download_feed feed_url
  uri = URI.parse(feed_url)
  rss = RSS::Parser.parse(uri)
  return rss
end

def generate_feed input_feed,baseurl
  RSS::Maker.make("2.0") do |maker|
    maker.channel.description = input_feed.channel.title
    maker.channel.generator = input_feed.channel.generator
    maker.channel.language = input_feed.channel.language
    maker.channel.lastBuildDate = input_feed.channel.lastBuildDate
    maker.channel.link = input_feed.channel.link
    maker.channel.managingEditor = input_feed.channel.managingEditor
    maker.channel.pubDate = input_feed.channel.pubDate
    maker.channel.title = input_feed.channel.title

    maker.items.do_sort = true

    input_feed.items.each do |in_item|
      key = in_item.link.scan(/(\w\w\d+)/).first.to_s

      item = maker.items.new_item
      item.description = in_item.description
      item.title = in_item.title.strip
      item.link = in_item.link
      item.pubDate = in_item.pubDate
      item.guid.content = in_item.guid.content
      item.guid.isPermaLink = in_item.guid.isPermaLink
      item.enclosure.url = "#{baseurl}/nicopodcast/content/#{key}.mp4"
      item.enclosure.type = "audio/mpeg"
      item.enclosure.length = "0"
    end
  end
end

def download(video_id,account_file,flv_file)
  account = YAML.load_file(account_file)
  mail = account['mail']
  password = account['password']
  nv = Nicovideo.new(mail, password)
  nv.login

  nv.watch(video_id) do |v|
    begin
      flv_file.write v.flv
    rescue Timeout::Error => e
      sleep 3
      puts "timeout error, retry"
      retry
    rescue => err
      p err
      throw err
    end 
  end
end

def encode flv,mp4
  ffmpeg_option = '-y -vcodec mpeg4 -r 23.976 -b 600k -acodec libfaac -ac 2 -ar 44100 -ab 128k'
  system "ffmpeg -i #{flv.path} #{ffmpeg_option} #{mp4.path}"
end
