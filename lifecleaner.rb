#!/usr/bin/env ruby

require 'twitter'
require 'json'
require 'date'
require 'yaml'

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

# handling config

begin

  setup = YAML.load_file 'lifecleaner.yml'

rescue

  puts 'please provide a readable lifecleaner.yml config file'
  exit 1

end

# go go go !

client = Twitter::REST::Client.new do |config|
  config.consumer_key = setup['consumer_key']
  config.consumer_secret = setup['consumer_secret']
  config.access_token = setup['access_token']
  config.access_token_secret = setup['access_token_secret']
end

tweets = client.user_timeline(setup['username'], {
                                    :count => 3200,
                                    :exclude_replies => false,
                                    :include_rts => true
                                  })


deleted_tweets = 0
deleted_favs = 0

puts "Loaded #{tweets.count} tweets"

# false to skip

if true

  tweets.each_with_index do |tweet, idx|

    removeId = tweet.id
    created_at = tweet.created_at

    begin

      if created_at.to_datetime < (Date.today - setup['days_before_deletion']) or tweet.text.include? '#LifeCleaner'

        puts "destroying tweet_id: #{removeId} #{created_at} [#{idx+1}/#{tweets.count}]"

        client.destroy_status(removeId)
        puts " > destroyed tweet_id: #{removeId}"

        deleted_tweets += 1 if !tweet.text.include? '#LifeCleaner'

        #sleep(0.5)

      else

        puts "keeping tweet_id: #{removeId} #{created_at} [#{idx+1}/#{tweets.count}]"

      end

    rescue => e
      puts "ooops: #{e} -- t_id: #{removeId}"
    end

  end

else

  puts "didn't process tweets"

end

favorites = client.favorites(setup['username'], {
                               :count => 3200
                             })

puts "Loaded #{favorites.count} favorites"

# false to skip

if true

  favorites.each_with_index do |fav, idx|

    removeId = fav.id
    created_at = fav.created_at

    begin

      if created_at.to_datetime < (Date.today - setup['days_before_deletion'])

        puts "unfav fav_id: #{removeId} [#{idx+1}/#{favorites.count}]"

        client.unfavorite(removeId)
        puts " > unfav'ed fav_id: #{removeId}"

        deleted_favs += 1

        #sleep(0.5)

      else

        puts "keeping fav_id: #{removeId} #{created_at} [#{idx+1}/#{favorites.count}]"

      end

    rescue => e
      puts "ooops: #{e} -- t_id: #{removeId}"
    end

  end

end

if (deleted_tweets+deleted_favs) > 0

  update_str = "Deleted #{deleted_tweets} tweets & #{deleted_favs} favorites older than #{setup['days_before_deletion']} days #LifeCleaner https://github.com/garnould/twitterstuff"

else

  update_str = "No tweet or favorite older than #{setup['days_before_deletion']} days was deleted #LifeCleaner https://github.com/garnould/twitterstuff"

end

client.update update_str

puts "'#{update_str}' sent to twitter"

exit 0
