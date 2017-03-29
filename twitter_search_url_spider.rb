# This is an example of how to combine a previous module of mine, SpidrTools
# with my Twitter API wrapper and a MySQL database, via mysql2 gem, to 
# aggregate email lists from Twitter searches. The primary method of operation
# is to use search terms from saved term lists to aggregate targeted tweets, 
# and then collect the URLs to be spidered for email addresses via RegEx matching.
# The results are committed to a database, as well as the websites (to be used as
# a redundancy check to prevent endless spidering of the same domains).

include SpidrTools
require 'mysql2'
require 'mechanize'
require 'spidr'

@agent = Mechanize.new
@emails = []

def harvest(url)
  begin
  puts url
  page = @agent.get(url)
  html = @agent.get(url).search('html').to_s
  mail = html.scan(/['.'\w|-]*@+[a-z]+[.]+\w{2,}/).map.to_a
  mail.each{|e| @emails << e unless e.include? "example.com" or  e.include? "email.com" or  e.include? "domain.com" or  e.include? "company.com" or e.length < 9 or e[0] == "@"}
  mail.each{|m| puts "+ "+m}

  base = url.split("//").last.split("/").first

  q = @sql.query("select url from websites where url=\"#{base}\"")
  puts q.size
  if q.size == 0
    http = url.split("://").first
    puts "Looking for contact page..."
    cpage = nil
    @bot = SpidrTools::Bot.new

    # This contact_page method searches for contact pages only, to optimize the search function

    cpage = @bot.contact_page("#{http}://#{base}")
    if cpage.nil?
      puts "No contact page."
      cpage = "none"
    else
      puts "Contact page = "+cpage
      page = @agent.get(cpage)
      html = @agent.get(cpage).search('html').to_s
      mail = html.scan(/['.'\w|-]*@+[a-z]+[.]+\w{2,}/).map.to_a
      mail.each{|e| @emails << e unless e.include? "example.com" or  e.include? "email.com" or  e.include? "domain.com" or  e.include? "company.com" or e.length < 9 or e[0] == "@"}
      mail.each{|m| puts "+ "+m}
    end
    @sql.query("insert into websites (url, contact_page) values ('#{base}', '#{cpage}');")
  end
  rescue Exception => e
    puts e
  end
end

files = Dir.entries("lists")

@terms = []
files.each do |file|
  unless file.include? "."
    File.open("lists/"+file){|f| @terms = @terms + f.read.to_s.split(",")}
  end
end
@terms.each do |term|
  posts = @twitter.search(term, options = {:limit => 100, :type => 'recent'})

  blacklist = File.open("blacklist").read.split("\n")

  urls = []
  posts.each do |post|
   flag = 0
   user = @twitter.user(post.user)
   url = user.expanded_url
   blacklist.each do |b|
     if url == nil or url == "" 
       flag = 1 
     else
       url = url.downcase
       if url.include? b
         flag = 1
       end
     end
   end
   if flag == 0
     urls << url
   end
  end
  urls.uniq.each do |url|
    harvest(url)
  end
end

@emails = @emails.uniq
@emails.each do |email|
  src = "twitterbot"
  email = @sql.escape(email)
  begin
    @sql.query("insert into email (address, source) values ('#{email}', '#{src}');")
    puts "Committed: #{email}"
  rescue Exception => e
    puts e
  end
end
