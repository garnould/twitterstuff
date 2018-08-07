#!/usr/bin/env ruby

#####################
### version

VERSION = '1.0.7'

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
              :force => false,
              :username => nil,
              :dump_config => false }

  opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--dryrun', '-d', GetoptLong::NO_ARGUMENT ],
    [ '--publish-status', '-n', GetoptLong::NO_ARGUMENT ],
    [ '--force', '-f', GetoptLong::NO_ARGUMENT ],
    [ '--dump-config', '-c', GetoptLong::NO_ARGUMENT ],
    [ '--username', '-u', GetoptLong::REQUIRED_ARGUMENT ],
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

      when '--dump-config'
        options[:dump_config] = true

      when '--username'
        options[:username] = arg

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
  puts "\t" + '--dump-config: shows config content and exits'
  puts "\t" + '--username user: cleans only one username (useful when having several in config)'

  exit 0

end

# handling config

begin

  setup = YAML.load_file File.dirname(__FILE__) + '/undertherug.yml'

rescue

  puts 'please provide a readable undertherug.yml config file'
  exit 1

end


# Casting single user config

if setup.is_a? Hash

  setup = [ setup.dup ]

end

# Checking config

error_detected = false

setup.each_index do |index|

  userconfig = setup[index]

  [ 'username', 'days_before_sweeping', 'consumer_key', 'consumer_secret', 'access_token', 'access_token_secret' ].each do |key|

    if !userconfig.has_key? key

      puts "config error at index ##{index}: no '#{key}' field" if !userconfig.has_key? 'username'
      puts "config error at index ##{index} for user '#{userconfig['username']}': no '#{key}' field" if userconfig.has_key? 'username'
      error_detected = true

    end

  end

  if userconfig.has_key? 'publish_status' and ![ 'never', 'cmdline', 'always' ].include? userconfig['publish_status']

      puts "config error at index ##{index}: invalid publish_status value '#{userconfig['publish_status']}'" if !userconfig.has_key? 'username'
      puts "config error at index ##{index} for user '#{userconfig['username']}':  invalid publish_status value '#{userconfig['publish_status']}'" if userconfig.has_key? 'username'
      error_detected = true

  end

end

exit 1 if error_detected

# Keeping only one username ?

if !options[:username].blank?

  setup.delete_if { |item| item['username'].downcase != options[:username].downcase }

end

# checking

if setup.length == 0

  puts 'invalid config (empty) or --username option (not found)'
  exit 1

end

# Some dump ?

if options[:dump_config]

  puts setup.class.to_s + ' : ' + setup.inspect
  exit 0

end

# an we go ?

if !options[:force] and !options[:dryrun]
  puts "--force has to be used when no --dryrun is used"
  exit 1
end

setup.each do |usersetup|

  # header

  puts "working on username #{usersetup['username']}"

  # fancy display

  puts "#{options[:dryrun] ? 'simulating sweeping of' : 'sweeping'} tweets and favorites older than #{usersetup['days_before_sweeping']} days"
  puts "dryrun mode activated, nothing really sent to twitter" if options[:dryrun]

  # go go go !

  client = Twitter::REST::Client.new do |config|
    config.consumer_key = usersetup['consumer_key']
    config.consumer_secret = usersetup['consumer_secret']
    config.access_token = usersetup['access_token']
    config.access_token_secret = usersetup['access_token_secret']
  end

  # counters

  swept_tweets = 0
  swept_favs = 0
  protected_tweets = 0
  kept_tweets = 0
  kept_favs = 0
  favorites_tweet_ids = Hash.new

  # handling favorites

  favorites = client.favorites(usersetup['username'], {
                                 :count => 3200
                               })

  puts "loaded #{favorites.count} favorites"

  favorites.each_with_index do |tweet, idx|

    # we set 0 when "unknown status", 1 when protecting tweet, 2 for retweet (and then won't be deleted after XXX days)

    favorites_tweet_ids[tweet.id] = 0

  end

  # handling tweets

  tweets = client.user_timeline(usersetup['username'], {
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

        if options[:sweep_status] or options[:publish_status] or (usersetup.has_key? 'publish_status' and usersetup['publish_status'] == 'never')

          puts "tweets: removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] #UnderTheRug hastag"

          client.destroy_status(removeId) if !options[:dryrun]

        else

          puts "tweets: not removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] #UnderTheRug hastag, force with --sweep-status"

          kept_tweets += 1

        end

      elsif favorites_tweet_ids.has_key?(removeId)

        favorites_tweet_ids[removeId] = 1

        puts "tweets: tweet #{removeId} protected by self-favorite"
        protected_tweets += 1

        kept_tweets += 1

      elsif tweet.retweet? and favorites_tweet_ids.has_key?(tweet.retweeted_status.id)

        favorites_tweet_ids[tweet.retweeted_status.id] = 2

        puts "tweets: tweet #{removeId} (retweet of #{tweet.retweeted_status.id}) protected by self-favorite"
        protected_tweets += 1

        kept_tweets += 1

      elsif created_at.to_datetime < (Date.today - usersetup['days_before_sweeping'])

        puts "tweets: removing #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] (too old)"

        client.destroy_status(removeId) if !options[:dryrun]
        swept_tweets += 1

      else

        puts "tweets: keeping #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] (fresh enough)"

        kept_tweets += 1

      end

    rescue => e

      puts "ooops: #{e} -- t_id: #{removeId}"

    end

  end

  # deleting too old favorites

  favorites.each_with_index do |tweet, idx|

    removeId = tweet.id
    created_at = tweet.created_at

    begin

      if favorites_tweet_ids[removeId] != 0

        puts "favorite: keeping #{removeId}, protecting self-favorite #{favorites_tweet_ids[removeId] == 1 ? '' : 're'}tweet [#{idx+1}/#{favorites.count}]"

      elsif created_at.to_datetime < (Date.today - usersetup['days_before_sweeping'])

        puts "favorite: removing #{removeId} #{created_at} [#{idx+1}/#{favorites.count}] (too old)"

        client.unfavorite(removeId) if !options[:dryrun]

        swept_favs += 1

      #sleep(0.5)

      else

        puts "favorite: keeping #{removeId} #{created_at} [#{idx+1}/#{favorites.count}] (fresh enough)"

        kept_favs += 1

      end

    rescue => e
      puts "ooops: #{e} -- t_id: #{removeId}"
    end

  end

  # fancy message

  puts "#{protected_tweets} protected tweets found"

  # updating twitter

  update_str = (swept_tweets+swept_favs) > 0 ?
                 "#{swept_tweets+swept_favs} tweets/favorites older than #{usersetup['days_before_sweeping']} days were swept #UnderTheRug #{VERSION} https://github.com/garnould/twitterstuff" :
                 "No tweet or favorite older than #{usersetup['days_before_sweeping']} days was swept #UnderTheRug #{VERSION} https://github.com/garnould/twitterstuff"

  if (options[:publish_status] and (!(usersetup.has_key? 'publish_status' and usersetup['publish_status'] == 'never'))) or (usersetup.has_key? 'publish_status' and usersetup['publish_status'] == 'always')

    client.update update_str if !options[:dryrun]

    puts "'#{update_str}' #{options[:dryrun] ? 'not ' : ''}really sent to twitter"

  else

    puts "--publish-status NOT in use, '#{update_str}' not sent to twitter"

  end

  puts "Kept #{kept_tweets+kept_favs} activities, including #{kept_favs} favs & #{kept_tweets} tweets (#{protected_tweets} protected)"

end

exit 0
