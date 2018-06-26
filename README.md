# twitterstuff

Some Twitter stuff to make life easier (quick and dirty)

At the moment, the only script is "undertherug.rb" : a tool that let you ~destroy your favorites/tweets automatically after a certain period of time.

## undertherug.rb

undertherug.rb let you ~destroy your favorites/tweets after a certain period of time.

Disclaimer: author does NOT believe that anything is actually deleted on Twitter platform, hence the name of this script. This script was renamed in order to have you keep in mind that your twitter activity is probably only hidden (under the rug) to other people eyes, but not to Twitter people.

Good to know: undertherub.rb skips any of your own tweets/RT you fav'ed, whatever their age.

### Setup

#### Config (undertherug.yml)

**undertherug.yml-sample** is a YAML formatted config file. It can support one or several users/accounts.

Keys are:

 * **username**: your screen name
 * **days_before_sweeping**: number of days your activities will last if not "self fav'ed" (tweets, RT)
 * **publish_status**: undertherug.rb can published a tweet of its own activity. Config file can override command line (never, always, cmdline)
 * **consumer_key**, **consumer_secret**, **access_token** and **access_token_secret** as taken from https://apps.twitter.com/ (Create New App)


#### Gems

Install any missing gems (twitter & json required)

 * $ gem install bundler
 * $ bundle install

### Run

Commandline option:

 * --help: help screen
 * --verbose [1-3]: verbosity (and optional level)
 * --dryrun/--force : mandatory
  * --dryrun: do NOT send any update to twitter, only show what should happen
  * --force: required to actually sweep tweets/favorites and eventually publish status
 * --publish-status: send any final status to twitter
 * --sweep-status: sweep previous #UnderTheRug tweets
 * --dump-config: shows config content and exits
 * --username user: cleans only one username (useful when having several in config)


### ChangeLog

#### 1.0.6

1. Multi-accounts support

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
