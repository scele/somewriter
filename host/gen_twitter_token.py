#!/usr/bin/env python3

import tweepy

# From your app settings page
CONSUMER_KEY = ""
CONSUMER_SECRET = ""

auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
auth.secure = True
auth_url = auth.get_authorization_url()

print('Please authorize: ' + auth_url)

verifier = raw_input('PIN: ').strip()

auth.get_access_token(verifier)

print("ACCESS_KEY = '%s'" % auth.access_token.key)
print("ACCESS_SECRET = '%s'" % auth.access_token.secret)
