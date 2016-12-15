#!/usr/bin/env ruby

require 'twitter'
require 'json'
require 'date'
require 'yaml'
require 'getoptlong'

#####################
### version

VERSION = '1.0.2'

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
### dirty imports

# extending Time class

class Time
  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end
end

# taken from activesupport-4.2.5/lib/active_support/core_ext/object/blank.rb

class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, +false+, '', '   ', +nil+, [], and {} are all blank.
  #
  # This simplifies
  #
  #   !address || address.empty?
  #
  # to
  #
  #   address.blank?
  #
  # @return [true, false]
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  # An object is present if it's not blank.
  #
  # @return [true, false]
  def present?
    !blank?
  end

  # Returns the receiver if it's present otherwise returns +nil+.
  # <tt>object.presence</tt> is equivalent to
  #
  #    object.present? ? object : nil
  #
  # For example, something like
  #
  #   state   = params[:state]   if params[:state].present?
  #   country = params[:country] if params[:country].present?
  #   region  = state || country || 'US'
  #
  # becomes
  #
  #   region = params[:state].presence || params[:country].presence || 'US'
  #
  # @return [Object]
  def presence
    self if present?
  end
end

class NilClass
  # +nil+ is blank:
  #
  #   nil.blank? # => true
  #
  # @return [true]
  def blank?
    true
  end
end

class FalseClass
  # +false+ is blank:
  #
  #   false.blank? # => true
  #
  # @return [true]
  def blank?
    true
  end
end

class TrueClass
  # +true+ is not blank:
  #
  #   true.blank? # => false
  #
  # @return [false]
  def blank?
    false
  end
end

class Array
  # An array is blank if it's empty:
  #
  #   [].blank?      # => true
  #   [1,2,3].blank? # => false
  #
  # @return [true, false]
  alias_method :blank?, :empty?
end

class Hash
  # A hash is blank if it's empty:
  #
  #   {}.blank?                # => true
  #   { key: 'value' }.blank?  # => false
  #
  # @return [true, false]
  alias_method :blank?, :empty?
end

class String
  BLANK_RE = /\A[[:space:]]*\z/

  # A string is blank if it's empty or contains whitespaces only:
  #
  #   ''.blank?       # => true
  #   '   '.blank?    # => true
  #   "\t\n\r".blank? # => true
  #   ' blah '.blank? # => false
  #
  # Unicode whitespace is supported:
  #
  #   "\u00a0".blank? # => true
  #
  # @return [true, false]
  def blank?
    BLANK_RE === self
  end
end

class Numeric #:nodoc:
  # No number is blank:
  #
  #   1.blank? # => false
  #   0.blank? # => false
  #
  # @return [false]
  def blank?
    false
  end
end

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

      puts "tweets: keeping #{removeId} #{created_at} [#{idx+1}/#{tweets.count}] (fresh enought)"

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
