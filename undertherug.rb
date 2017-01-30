#!/usr/bin/env ruby

#####################
### version

VERSION = '1.0.2f'

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
              :dryrun => false,
              :publish_status => false,
              :sweep_status => false,
              :force => false }

  opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--dryrun', '-d', GetoptLong::NO_ARGUMENT ],
    [ '--publish-status', '-n', GetoptLong::NO_ARGUMENT ],
    [ '--force', '-f', GetoptLong::NO_ARGUMENT ],
    [ '--sweep-status', '-s', GetoptLong::NO_ARGUMENT ] )

  begin

    opts.each do |opt, arg|
      case opt
      when '--help'
        options[:help] = true ;

      when '--verbose'
        options[:verbose] = options[:verbose] + ( arg.blank? ? 1 : arg.to_i )

      when '--dryrun'
        options[:dryrun] = true

      when '--publish-status'
        options[:publish_status] = true

      when '--sweep-status'
        options[:sweep_status] = true

      when '--force'
        options[:force] = true

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

puts "undertherug.rb"

# handling command line

options = parseCommandLine()

exit 1 if options.nil?

# checking options

if options[:help]

  puts 'undertherug.rb usage:'
  puts "\t" + '--help: this screen'
  puts "\t" + '--verbose [1-3]: verbosity (and optional level)'
  puts "\t" + '--dryrun: do NOT send any update to twitter, only show what should happen'
  puts "\t" + '--publish-status: send any final status to twitter'
  puts "\t" + '--sweep-status: sweep previous #UnderTheRug tweets'
  puts "\t" + '--force: required to actually sweep tweets/favorites'

  exit 0

end

# handling config

begin

  setup = YAML.load_file 'undertherug.yml'

rescue

  puts 'please provide a readable undertherug.yml config file'
  exit 1

end

# an we go ?

if !options[:force] and !options[:dryrun]
  puts "--force has to be used when no --dryrun is used"
  exit 1
end

# fancy display

puts "#{options[:dryrun] ? 'simulating sweeping of' : 'sweeping'} tweets and favorites older than #{setup['days_before_sweeping']} days"
puts "dryrun mode activated, nothing really sent to twitter" if options[:dryrun]

# go go go !

client = Twitter::REST::Client.new do |config|
  config.consumer_key = setup['consumer_key']
  config.consumer_secret = setup['consumer_secret']
  config.access_token = setup['access_token']
  config.access_token_secret = setup['access_token_secret']
end

# counters

swept_tweets = 0
swept_favs = 0
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

      puts "favorite: keeping #{removeId}, protecting self-favorite tweet"
      tweets_protected_by_favorites[removeId] = 1

    elsif created_at.to_datetime < (Date.today - setup['days_before_sweeping'])

      puts "favorite: removing #{removeId} #{created_at} [#{idx+1}/#{favorites.count}]"

      client.unfavorite(removeId) if !options[:dryrun]

      swept_favs += 1

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

    if tweet.text.include?('#UnderTheRug')

      if options[:sweep_status] or options[:publish_status]

        puts "tweets: removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] #UnderTheRug hastag"

        client.destroy_status(removeId) if !options[:dryrun]

      else

        puts "tweets: not removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] #UnderTheRug hastag, force with --sweep-status"

      end

    elsif tweets_protected_by_favorites.has_key?(removeId)

      puts "tweets: tweet #{removeId} protected by self-favorite"
      protected_tweets += 1

    elsif created_at.to_datetime < (Date.today - setup['days_before_sweeping'])

      puts "tweets: removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] (too old)"

      client.destroy_status(removeId) if !options[:dryrun]
      swept_tweets += 1

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

update_str = (swept_tweets+swept_favs) > 0 ?
               "#{swept_tweets+swept_favs} tweets/favorites older than #{setup['days_before_sweeping']} days were swept #UnderTheRug #{VERSION} https://github.com/garnould/twitterstuff" :
               "No tweet or favorite older than #{setup['days_before_sweeping']} days was swept #UnderTheRug #{VERSION} https://github.com/garnould/twitterstuff"

if options[:publish_status]


  client.update update_str if !options[:dryrun]

  puts "'#{update_str}' #{options[:dryrun] ? 'not ' : ''}really sent to twitter"

else

  puts "--publish-status NOT in use, '#{update_str}' not sent to twitter"

end

exit 0
