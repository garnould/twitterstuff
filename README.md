# twitterstuff

some Twitter stuff to make life easier (quick and dirty)

## undertherug.rb

Hides your tweets and favorites older than X days under the rug.

Fav your own tweets to protect them from sweeping

### Setup

1. copy **undertherug.yml-sample** to **undertherug.yml**
2. edit **undertherug.yml** and set:
 1. Your twitter username (**username**)
 2. The number of days until your tweets and favs are swept (**days_before_sweeping**)
 3. **consumer_key**, **consumer_secret**, **access_token** and **access_token_secret** as taken from https://apps.twitter.com/ (Create New App)
3. install any missing gems (twitter & json required)
 1. $ gem install bundler
 2. $ bundle install

### Run

1. help: $ ./undertherug.rb --help
2. dry run: $ ./undertherug.rb --dryrun
3. sweeping old tweets: $ ./undertherug.rb --force


### ChangeLog

#### 1.0.3

1. support several accounts in a single config file
2. improved config checking

#### 1.0.2f

1. renamed the wrongly named lifecleaner.rb to undertherug.rb.

#### 1.0.2

1. getoptlong gem required, see --help for details
2. feature: you can protect your tweets from being swept if too old by favoriting those updates (self favorited tweets are not swept).

#### first commit

1. Processing tweets/favorites older than X days  and sending an update to tweeter
