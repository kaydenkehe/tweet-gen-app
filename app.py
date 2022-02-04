from werkzeug.serving import WSGIRequestHandler
from tweet_generate import generate_tweets
from flask import Flask, request

app = Flask(__name__)

@app.route('/get_ai')
def get_ai():
    # Get Twitter username and training time from url queries
    user_name = request.args.get('username').replace('@', '')
    max_time = int(float(request.args.get('time')))

    if max_time >= 1 and max_time <= 10:
        try:
            generated_tweet_list, accuracy, tweet_len, actual_tweets = generate_tweets(user_name, 300, 30, max_time)
            if generated_tweet_list != None: # If generated_tweet_list is None, then the submitted username doesn't exist
                # Create a dictionary from data receieved from generate_tweets and send it as a JSON response
                generated_tweet_dict = {'accuracy': accuracy, 'tweet_len': tweet_len, 'gen_tweets': {}, 'actual_tweets': {}}
                for i in range(len(generated_tweet_list)): generated_tweet_dict['gen_tweets'][i] = generated_tweet_list[i]
                for i in range(len(actual_tweets)): generated_tweet_dict['actual_tweets'][i] = actual_tweets[i]
                return generated_tweet_dict

            else: return 'bad_username'

        except: return 'error'

# This path is used by the app to verify that the server is running
@app.route('/test_api')
def test_api(): return 'working'

# Run website on port 7496 on current machine
if __name__=='__main__':
    # https://gitanswer.com/flutter-connection-closed-while-receiving-data-dart-369081623
    # I don't know what this line does, but it fixes a bug where Flutter occasionally doesn't receive the response from the GET request
    WSGIRequestHandler.protocol_version = 'HTTP/1.1'
    app.run(debug=False, port=7496, host='0.0.0.0')
