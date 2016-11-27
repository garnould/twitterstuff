# twitterstuff
Some Twitter stuff to make life easier (quick and dirty)

## lifecleaner.rb
Delete tweets and favs older than X days

### Setup

1. copy **lifecleaner.yml-sample** to **lifecleaner.yml**
2. edit **lifecleaner.yml** and set:
 1. Your twitter username (username)
 2. The number of days until your tweets and favs are deleted (days_before_deletion)
 3. consumer_key, consumer_secret, access_token and access_token_secret as taken from from https://apps.twitter.com/ (Create New App)
3. install and missing gems (twitter, yaml, date and json required)

### Run

$ ./lifecleaner.rb
