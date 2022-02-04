from requests import post, get
from re import compile
from time import time

authorization_header = 'PUT YOUR AUTHORIZATION HEADER HERE'

# Grabs a value for the x-guest-token header, which is the only uniquely identifying and time-limited header/parameter needed in the whole script
def get_guest_token():
    headers = {'authorization': authorization_header}
    response = post('https://api.twitter.com/1.1/guest/activate.json', headers=headers)
    token = response.json()['guest_token']
    return token

# Scrapes some number of tweets from a certain user and returns a list
# This function works by sending GET requests to twitter and parsing JSON responses for tweet contents
# The twitter.com/search url which we're scraping from uses infinite scrolling to load more tweets
# Twitter determines where you're scrolling to using a parameter in the request called 'cursor'
# The value that 'cursor' needs to be set to to scroll down is found in the same JSON object that contains the tweet contents

# SOME CODE FROM THIS FUNCTION WAS TAKEN FROM OR INSPIRED BY CODE FROM THE SNSCRAPE MODULE
# https://pypi.org/project/snscrape/ | https://pypi.org/user/JustAnotherArchivist/
def scrape_tweets(user_name, num_tweets):
    past_first_scroll = False # Helps keep track of whether we've scrolled more than once because after the first scroll, the new value of 'cursor' that we need is found in a slightly differet place
    link_regex = compile(r'https://\S+') # Helps remove links from tweets
    at_regex = compile(r'@\w+ ') # Helps remove @s from tweets
    cursor = None
    new_cursor = None # Helps determine if the cursor has changed
    tweets = []
    retry_count = 0
    retry_max = 10

    # Parameters for http requests
    # The params dictionary here was taken directly from the snscrape module. This one worked better than the one I made myself
    params = {
        'include_profile_interstitial_type': '1',
		'include_blocking': '1',
		'include_blocked_by': '1',
		'include_followed_by': '1',
		'include_want_retweets': '1',
		'include_mute_edge': '1',
		'include_can_dm': '1',
		'include_can_media_tag': '1',
		'skip_status': '1',
		'cards_platform': 'Web-12',
		'include_cards': '1',
		'include_ext_alt_text': 'true',
		'include_quote_count': 'true',
		'include_reply_count': '1',
		'include_entities': 'true',
		'include_user_entities': 'true',
		'include_ext_media_color': 'true',
		'include_ext_media_availability': 'true',
		'send_error_codes': 'true',
		'simple_quoted_tweets': 'true',
        'tweet_mode': 'extended',
		'q': f'from:{user_name}', # This is what would go inside the search box in twitter.com/search
		'tweet_search_mode': 'live',
		'count': '100',
		'query_source': 'spelling_expansion_revert_click',
		'cursor': cursor,
		'pc': '1',
		'spelling_corrections': '1',
		'ext': 'mediaStats,highlightedLabel'
    }

    # Headers for http requests
    headers = {
        'authorization': authorization_header,
        'x-guest-token': get_guest_token()
    }

    # Keep getting new tweets until either we have the amount we need, or we've exceeded the retry limit
    while len(tweets) < num_tweets and retry_count < retry_max:
        params['cursor'] = cursor # Update cursor value in parameters
        tweet_data = get('https://twitter.com/i/api/2/search/adaptive.json', params=params, headers=headers).json()

        # Find the new value needed for 'cursor'
        if past_first_scroll:
            for j in tweet_data['timeline']['instructions']:
                if 'replaceEntry' in j:
                    if j['replaceEntry']['entryIdToReplace'] == 'sq-cursor-bottom':
                        new_cursor = j['replaceEntry']['entry']['content']['operation']['cursor']['value'] 
        else:
            entries = tweet_data['timeline']['instructions'][0]['addEntries']['entries']
            for entry in entries:
                if entry['sortIndex'] == '0':
                    new_cursor = entry['content']['operation']['cursor']['value']
            past_first_scroll = True

        # If the new 'cursor' value is different (we've successfully scrolled down), append the tweets to the list
        if cursor != new_cursor:
            retry_count = 0
            for i in tweet_data['globalObjects']['tweets']:
                tweets.append(at_regex.sub('', link_regex.sub('', tweet_data['globalObjects']['tweets'][i]['full_text']).encode('ascii', errors='ignore').decode().replace('&amp;', '&')))
                if tweets[len(tweets) - 1] == '' or tweets[len(tweets) - 1] == ' ': tweets.pop()
        # If not, increment the retry count
        else: retry_count += 1

        cursor = new_cursor

    return tweets[:num_tweets]



# This is here for debugging / testing
if __name__=='__main__':
    start_time = time()

    user_name = 'magicrealismbot' # Username of Twitter account
    num_tweets = 200 # Number of tweets to scrape
    tweets = scrape_tweets(user_name, num_tweets)

    end_time = time()

    for tweet in tweets: print(tweet)
    print(f'\nNum Tweets: {len(tweets)}')
    print(f'Num Unique Tweets: {len(set(tweets))}')
    print(f'Time: {end_time - start_time}')
