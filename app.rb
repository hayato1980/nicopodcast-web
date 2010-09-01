# -*- coding: utf-8 -*-


require 'rubygems'
require 'sinatra'
require 'sinatra/x_send_file'
require 'rss'
require 'nicovideo'

get '/' do
  'Hello! nicopodcast'
end

get '/nicopodcast/feed/:mylistid' do
  GC.start

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
  GC.start
  movieid = params[:splat].first
  content_type :mp4
  begin
    tempdir = "/tmp"
    flv = Tempfile.open("#{movieid}.flv",tempdir)

    download(movieid,"#{ENV['CONFIG']}/account.yml",flv)
    GC.start
    mp4 = "#{tempdir}/#{movieid}.mp4"
    encode flv,mp4
    x_send_file mp4

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
  puts "start download #{video_id}"
  account = YAML.load_file(account_file)
  mail = account['mail']
  password = account['password']
  nv = Nicovideo.new(mail, password)
  nv.login

  nv.watch(video_id) do |v|
    begin
      flv_file.write v.flv
      puts "finish download #{video_id}"
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
  puts "start ffmpeg #{mp4}"
  ffmpeg_option = '-y -vcodec mpeg4 -r 23.976 -b 600k -acodec libfaac -ac 2 -ar 44100 -ab 128k'
  begin
    system "ffmpeg -i #{flv.path} #{ffmpeg_option} #{mp4} > /dev/null 2>&1"
  rescue Errono::ENOMEM
    GC.start
    puts "sleep 30 because nomemory for ffmpeg"
    sleep 30
    retry
  end
  puts "finish ffmpeg #{mp4}"
end
