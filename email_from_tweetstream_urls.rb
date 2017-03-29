require 'tweetstream'
require 'json'
require 'mechanize'

@agent = Mechanize.new
@blacklist = File.open("blacklist").read.split("\n")
TweetStream.configure do |config|
  config.oauth_token        = # OAuth Token
  config.oauth_token_secret = # Oauth Token Secret
  config.consumer_key       = # Consumer Key
  config.consumer_secret    = # 
  config.auth_method        = :oauth
end

def harvest(url)
  begin
  page = @agent.get(url)
  html = @agent.get(url).search('html').to_s
  mail = html.scan(/['.'\w|-]*@+[a-z]+[.]+\w{2,}/).map.to_a
  mail.each{|e| @emails << e unless e.length < 9 or e[0] == "@"}
  rescue Exception => e
    puts e
  end
end

TweetStream::Client.new.sample do |status|
  uris = status.uris
  uris.each do |url|
    ats = url.attrs
    url = ats[:expanded_url]
    @emails = []
    f = 0
    @blacklist.each do |b|
      if url.include? b
        f = 1
      end
    end
    if f == 0 
      harvest(url)
      @emails.uniq.each do |email|
        puts email
      end
    else
      puts "Skipping url..."
    end
  end
end
