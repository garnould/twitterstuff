# twitterstuff
Some Twitter stuff to make life easier (quick and dirty)

## lifecleaner.rb
Delete tweets and favs older than X days

### Setup

1. copy **lifecleaner.yml-sample** to **lifecleaner.yml**
2. edit **lifecleaner.yml** and set:
 1. Your twitter username (**username**)
 2. The number of days until your tweets and favs are deleted (**days_before_deletion**)
 3. **consumer_key**, **consumer_secret**, **access_token** and **access_token_secret** as taken from https://apps.twitter.com/ (Create New App)
3. install any missing gems (twitter & json required)
 1. $ gem install bundler
 2. $ bundle install

### Run

1. help: $ ./lifecleaner.rb --help
2. dry run: $ ./lifecleaner.rb --dryrun --verbose --verbose
3. deleting old tweets: $ ./lifecleaner.rb --verbose --verbose


### ChangeLog

#### first commit

1. Processing tweets/favorites older than X days  and sending an update to tweeter

#### 1.0.2

1. getoptlong gem required, see --help for details
2. feature: you can protect your tweets from being deleted if too old by favoriting those updates (self favorited tweets are not deleted)