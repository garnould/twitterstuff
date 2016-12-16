#!/usr/bin/env ruby

#####################
### version

VERSION = '1.0.2b'

#####################
# locate me (root receives script's directory)

root = File.expand_path(File.dirname(__FILE__))

#####################
# requiring

require 'twitter'
require 'json'
require 'date'
require 'yaml'
require 'getoptlong'
require "#{root}/lib/blank.rb"
require "#{root}/lib/time.rb"

#####################
### subs

def parseCommandLine

  options = { :help => false,
              :verbose => 0,
              :dryrun => false }

  opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--dryrun', '-d', GetoptLong::NO_ARGUMENT ] )

  begin

    opts.each do |opt, arg|
      case opt
      when '--help'
        options[:help] = true ;

      when '--verbose'
        options[:verbose] = options[:verbose] + ( arg.blank? ? 1 : arg.to_i )

      when '--dryrun'
        options[:dryrun] = true

      end
    end

  rescue GetoptLong::MissingArgument


    puts 'error while parsing command line'
    return nil

  end

  return options

end

#####################
# main begins here ...

puts "lifecleaner.rb"

# handling command line

options = parseCommandLine()

exit 1 if options.nil?

# checking options

if options[:help]

  puts 'lifecleaner.rb usage:'
  puts "\t" + '--help: this screen'
  puts "\t" + '--verbose [1-3]: verbosity (and optional level)'
  puts "\t" + '--dryrun: do NOT send any update to twitter, only show what should happen'

  exit 0

end


# handling config

begin

  setup = YAML.load_file 'lifecleaner.yml'

rescue

  puts 'please provide a readable lifecleaner.yml config file'
  exit 1

end

# fancy display

puts "#{options[:dryrun] ? 'simulating deletion of' : 'deleting'} tweets and favorites older than #{setup['days_before_deletion']} days"
puts "dryrun mode activated, nothing really sent to twitter" if options[:dryrun]

# go go go !

client = Twitter::REST::Client.new do |config|
  config.consumer_key = setup['consumer_key']
  config.consumer_secret = setup['consumer_secret']
  config.access_token = setup['access_token']
  config.access_token_secret = setup['access_token_secret']
end

# counters

deleted_tweets = 0
deleted_favs = 0
protected_tweets = 0
tweets_protected_by_favorites = Hash.new

# handling favorites

favorites = client.favorites(setup['username'], {
                               :count => 3200
                             })

puts "loaded #{favorites.count} favorites"

favorites.each_with_index do |tweet, idx|

  removeId = tweet.id
  created_at = tweet.created_at

  begin

    if tweet.user.screen_name == setup['username']

      puts "favorite: tweet #{removeId} protected by self-favorite"
      tweets_protected_by_favorites[removeId] = 1

    elsif created_at.to_datetime < (Date.today - setup['days_before_deletion'])

      puts "favorite: removing #{removeId} #{created_at} [#{idx+1}/#{favorites.count}]"

      client.unfavorite(removeId) if !options[:dryrun]

      deleted_favs += 1

    #sleep(0.5)

    else

      puts "favorite: keeping #{removeId} #{created_at} [#{idx+1}/#{favorites.count}]"

    end

  rescue => e
    puts "ooops: #{e} -- t_id: #{removeId}"
  end

end

# handling tweets

tweets = client.user_timeline(setup['username'], {
                                    :count => 3200,
                                    :exclude_replies => false,
                                    :include_rts => true
                                  })

puts "loaded #{tweets.count} tweets"

tweets.each_with_index do |tweet, idx|

  removeId = tweet.id
  created_at = tweet.created_at

  begin

    if created_at.to_datetime < (Date.today - setup['days_before_deletion']) or tweet.text.include? '#LifeCleaner'

      if tweets_protected_by_favorites.has_key? removeId and !tweet.text.include? '#LifeCleaner'

        puts "tweets: tweet #{removeId} protected by self-favorite"
        protected_tweets += 1

      else

        puts "tweets: removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}]#{tweet.text.include?('#LifeCleaner') ? ' #LifeCleaner hastag' : ''}"

        client.destroy_status(removeId) if !options[:dryrun]

        deleted_tweets += 1 if !tweet.text.include? '#LifeCleaner'

      end

    else

      puts "tweets: keeping #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] (fresh enough)"

    end

  rescue => e
    puts "ooops: #{e} -- t_id: #{removeId}"
  end

end

# fancy message

puts "#{protected_tweets} protected tweets found"

# updating twitter

if (deleted_tweets+deleted_favs) > 0

  update_str = "#{deleted_tweets+deleted_favs} tweets/favorites older than #{setup['days_before_deletion']} days were deleted #LifeCleaner #{VERSION} https://github.com/garnould/twitterstuff"

else

  update_str = "No tweet or favorite older than #{setup['days_before_deletion']} days was deleted #LifeCleaner #{VERSION} https://github.com/garnould/twitterstuff"

end

client.update update_str if !options[:dryrun]

puts "'#{update_str}' sent to twitter"

exit 0
