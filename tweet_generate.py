from tensorflow.keras.layers import Embedding, LSTM, Dropout, Dense
from tensorflow.keras.preprocessing.sequence import pad_sequences
from tensorflow.keras.preprocessing.text import Tokenizer
from tensorflow.keras.initializers import Constant
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import Callback
from tensorflow.keras.models import Sequential

from numpy.random import normal, permutation, choice as npchoice
from numpy import std, mean, fromstring, zeros, argmax

from random import choice, sample, randrange
from tweet_scrape import scrape_tweets
from time import time

def generate_tweets(user_name, num_tweets, num_to_generate, max_time_min):
    start_time = time()


    # -- SCRAPE / PREPROCESS TWEETS --


    # If tweet scraping fails too many times, abort the program
    retry_max = 10
    retry_count = 0
    while retry_count <= retry_max:
        try:
            tweets = scrape_tweets(user_name, num_tweets) # Scrape tweets from Twitter
            break
        except: retry_count += 1

    if len(tweets) < 30: return None, None, None, None # Some parts of the app won't work if the user has fewer than 30 tweets

    # Tokenize tweets (Represent each word in each tweet as an integer)
    tokenizer = Tokenizer(filters='()"', lower=False)
    tokenizer.fit_on_texts(tweets)
    word_index = tokenizer.word_index
    vocab_len = len(word_index) + 1
    tokenized_tweets = tokenizer.texts_to_sequences(tweets)

    # Split tweets up
    # ['i', 'am', 'a', 'cool', 'cat'] becomes [['i', 'am'], ['i', 'am', 'a'], ['i', 'am', 'a', 'cool'], ['i', 'am', 'a', 'cool', 'cat']] (but tokenized)
    split_tweets = []
    for tokenized_tweet in tokenized_tweets:
        for i in range(1, len(tokenized_tweet)):
            split_tweets.append(tokenized_tweet[:i + 1])

    try: padded_tweets = pad_sequences(split_tweets, padding='pre') # Pad each tweet so they're all the same length
    except: return None, None, None, None

    # Create input and label sets from padded tweets
    # ['i', 'am', 'a', 'cool', 'cat'] becomes input = ['i', 'am', 'a', 'cool'] and label = ['cat'] (but tokenized)
    inputs = padded_tweets[:, :-1]
    labels = to_categorical(padded_tweets[:, -1], num_classes=vocab_len)
    
    # Randomly shuffle dataset
    shuffler = permutation(len(inputs))
    inputs = inputs[shuffler]
    labels = labels[shuffler]


    # -- GloVe EMBEDDING --
    # This section is taken from the Keras documentation on pre-trained word embeddings
    # https://keras.io/examples/nlp/pretrained_word_embeddings/


    embed_dim = 100 # Size of word embedding vector

    # Map words to their vectors
    embeddings_index = {}
    with open(f'C:\\Users\\kayde\\Desktop\\glove\\glove.6B.{embed_dim}d.txt', encoding='utf8') as f:
        for line in f:
            word, coefs = line.split(maxsplit=1)
            coefs = fromstring(coefs, "f", sep=" ")
            embeddings_index[word] = coefs

    # Use embeddings_index to create a usable embedding layer matrix
    embedding_matrix = zeros((vocab_len, embed_dim))
    for word, i in word_index.items():
        embedding_vector = embeddings_index.get(word)
        if embedding_vector is not None:
            embedding_matrix[i] = embedding_vector


    # -- MACHINE LEARNING MODEL --


    # Create model
    sequence_len = len(inputs[0])
    model = Sequential([
        Embedding(input_dim=vocab_len, output_dim=embed_dim, input_length=sequence_len, embeddings_initializer=Constant(embedding_matrix), trainable=False, mask_zero=True), # This layer represents each token as a specific vector
        LSTM(125),
        Dropout(0.15),
        Dense(vocab_len, activation='softmax')
    ])

    model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy']) # Compile the model

    # This class allows training to be stopped when time in minutes has exceeded max_time_min
    max_time_seconds = max_time_min * 60
    class early_stop_callback(Callback):
        def on_epoch_end(self, epoch, logs={}):
            if time() - start_time >= max_time_seconds:
                self.accuracy = logs.get('accuracy')
                self.model.stop_training = True
    callback = early_stop_callback()

    model.fit(inputs, labels, epochs=10000, batch_size=32, verbose=1, callbacks=callback) # Train the model
    accuracy = round(callback.accuracy * 100)


    # -- GET PREDICTIONS --


    # These will be used for the normal distribution that determines how long each tweet will be
    tweet_lengths = [len(tweet.split(' ')) for tweet in tweets]
    tweet_std = std(tweet_lengths)
    tweet_mean = mean(tweet_lengths)

    # Generate a tweet using the model
    def generate_tweet(first_words):
        word_list = [first_words] # In each iteration, every word in this list is used as input for the next predicted word
 
        # Predict more words for the tweet. The amount of words to predict is calculated using a normal distribution based on previous tweets
        tweet_word_count = round(normal(loc=tweet_mean, scale=tweet_std, size=1)[0]) - 2
        tweet_done = False
        while not tweet_done:
            input = pad_sequences(tokenizer.texts_to_sequences(word_list), maxlen=sequence_len, padding='pre') # Tokenize and pad the inputs
            prediction = model.predict(input) # Get model prediction

            # 1/4 chance of using probability and 3/4 chance of using argmax to get next word. Helps prevent repitition in low accuracies
            if randrange(4) == 0:  new_tokenized_word = npchoice(len(prediction[0]), p=prediction[0])
            else: new_tokenized_word = argmax(prediction, axis=-1)[0]

            new_word = list(word_index.keys())[list(word_index.values()).index(new_tokenized_word)] # Convert model predicted token to word
            word_list[0].append(new_word)

            # Stop predicting if the tweet is longer than tweet_word_count or the tweet has exceeded 280 characters
            if len(word_list[0]) >= tweet_word_count: tweet_done = True
            elif len(' '.join(word_list[0])) >= 280:
                word_list[0].pop()
                tweet_done = True

        tweet = ' '.join(word_list[0])
        return tweet

    # Generate tweets using the generate_tweet function
    generated_tweets = []
    done_generating = False
    while not done_generating:
        # Pick a random real tweet and use its first two words as the seed for the prediction
        random_first_tweet = choice(tweets).split(' ')
        if len(random_first_tweet) > 1:
            first_words = [random_first_tweet[0], random_first_tweet[1]]
            generated_tweet = generate_tweet(first_words)
            if generated_tweet not in tweets: generated_tweets.append(generated_tweet) # Make sure the generated Tweet isn't the exact same as a real one

        if len(generated_tweets) == num_to_generate: done_generating = True

    return generated_tweets, accuracy, len(tweets), sample(tweets, 30)



# This is here for debugging / testing
if __name__=='__main__':
    start_time = time()

    user_name = 'magicrealismbot' # Twitter username
    num_to_generate = 30 # Number of tweets to generate
    max_time_min = 1 # Max training/scraping time in minutes
    num_tweets = 300 # Number of tweets to scrape for training
    generated_tweets, accuracy, tweet_len, actual_tweets = generate_tweets(user_name, num_tweets, num_to_generate, max_time_min)

    for tweet in generated_tweets: print(tweet + '\n')
    print(f'Accuracy: {accuracy}%')
    print(f'Num Scraped Tweets: {tweet_len}')
    print(f'Time: {round((time() - start_time) / 60, 2)}m')
