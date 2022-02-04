import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as requests;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';


// Colors
var DarkBG = Color(0xff131A22);
var MedBG = Color(0xff232F3E);
var LightBG = Color(0xff2E3E52);
var TextColor = Color(0xffD4D4D4);
var ActiveColor = Color(0xffFFA642);


void main() => runApp(Home());


// -- GLOBAL VARIABLES --


// Generated and actual Tweet lists
var GenTweetList = List<String>.filled(30, '');
var RealTweetList = List<String>.filled(30, '');

// Variables related to the home page
double ModelAccuracy = 0.0;
bool ProgressVisible = false;
bool ProgressPlaceHolderVisible = true;
bool GenTweetListVisible = false;
int ProgressTime = 0;
bool ButtonsEnabled = true;

// Variables related to the game page
var GameQuestionList = List<String>.filled(40, '');
var GameAnswerList = List<int>.filled(10, 0);
int GamePageVisibilityLevel = 0;
int CurrentQuestion = 0;
int NumQuestionCorrect = 0;


// -- MAIN PAGE --


class Home extends StatelessWidget {
  const Home({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
    ]);
    return MaterialApp (
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // https://stackoverflow.com/questions/59143443/how-to-make-flutter-app-font-size-independent-from-device-settings
        // This makes the font size independent of the device settings
        return MediaQuery (
          child: child!,
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
        );
      },
      theme: ThemeData (
        scaffoldBackgroundColor: MedBG,
      ),
      home: MyApp(),
    );
  }
}


// -- APPBAR / NAVBAR / PAGE HANDLER --


class MyApp extends StatefulWidget {
  const MyApp({ Key? key }) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int CurrentPage = 1;
  
  void ChangePage(int newPage) {
    setState(() {
      if (ButtonsEnabled == true) {
        CurrentPage = newPage;
      }
      else {
        Alert("You can't navigate while the AI is training!", context);
      }
    });
  }

  final Pages = [
    Game(),
    Body(),
    Info(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      resizeToAvoidBottomInset: false,
      appBar: AppBar (
          backgroundColor: DarkBG,
          foregroundColor: ActiveColor,
          title: Text('AI Tweet Generator'),
          centerTitle: true,
          elevation: 0.0,
      ),
      body: Pages[CurrentPage],
      bottomNavigationBar: BottomNavigationBar (
        backgroundColor: DarkBG,
        onTap: ChangePage,
        currentIndex: CurrentPage,
        unselectedItemColor: TextColor,
        selectedItemColor: ActiveColor,
        items: [
          BottomNavigationBarItem (
            icon: Icon(Icons.videogame_asset),
            label: 'Game',
          ),
          BottomNavigationBarItem (
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem (
            icon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}


// -- HOME PAGE --


class Body extends StatefulWidget {
  const Body({ Key? key }) : super(key: key);

  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  TextEditingController UsernameController = TextEditingController();
  double sliderVal = 1;

  // Get data from server
  GetData(String user_name, double time) async {
    try {await requests.get(Uri.parse('http://72.192.95.115:7496/test_api')).timeout(Duration(seconds: 20));}
    on TimeoutException {return 'server_down';}

    try {
      requests.Response tweet_response = await requests.get(Uri.parse('http://72.192.95.115:7496/get_ai?username=' + user_name + '&time=' + time.toString()));
      return tweet_response.body;
    }
    catch(e) {
      Alert('Something went wrong', context);
      setState(() {
        CurrentQuestion = 0;
        NumQuestionCorrect = 0;
        ModelAccuracy = 0.0;
        ProgressPlaceHolderVisible = true;
        GenTweetListVisible = false;
        ProgressVisible = false;
        ProgressTime = sliderVal.round();
        ButtonsEnabled = true;
      });
    }
  }

  // Create answer and question list for games
  CreateGameData () {
    var RealTweetListTemp = List.generate(RealTweetList.length, (i) => RealTweetList[i], growable: true);
    var GenTweetListTemp = List.generate(GenTweetList.length, (i) => GenTweetList[i], growable: true).sublist(0, 10);

    int answerPlacement = 0;
    for (int i = 0; i < 10; i++) {
      var RNG = new Random();
      answerPlacement = RNG.nextInt(4);
      GameAnswerList[i] = answerPlacement;

      for (int j = 0; j < 4; j++) {
        if (j == answerPlacement) {
          GameQuestionList[i * 4 + j] = GenTweetListTemp[0];
          GenTweetListTemp.remove(GenTweetListTemp[0]);
        }
        else {
          GameQuestionList[i * 4 + j] = RealTweetListTemp[0];
          RealTweetListTemp.remove(RealTweetListTemp[0]);
        }
      }
    }
  }

  // Handle submit button press
  SubmitPress() async {
    String TwitterUser = UsernameController.text;

    if (TwitterUser == '') {
      Alert('Please enter a Twitter username', context);
    }
    else {
      // Reset a bunch of widgets and values
      setState(() {
        CurrentQuestion = 0;
        NumQuestionCorrect = 0;
        ModelAccuracy = 0.0;
        ProgressPlaceHolderVisible = false;
        GenTweetListVisible = false;
        ProgressVisible = true;
        ProgressTime = sliderVal.round();
        ButtonsEnabled = false;
      });

      // Get data from server
      String tweetResponseStr = await GetData(TwitterUser, sliderVal);
      if (tweetResponseStr == 'server_down' || tweetResponseStr == 'bad_username' || tweetResponseStr == 'error') {
        // Alert user if there was a problem getting the data
        if (tweetResponseStr == 'server_down') {Alert('Unable to connect to server.', context);}
        else if (tweetResponseStr == 'bad_username') {Alert('Twitter account "@${TwitterUser}" does not exist or has fewer than 30 Tweets.', context);}
        else {Alert('An error has occured', context);}

        setState(() {
          ProgressVisible = false;
          ProgressPlaceHolderVisible = true;
          ButtonsEnabled = true;
        });
      }
      else {
        var tweetResponseJSON = jsonDecode(tweetResponseStr);
        if (tweetResponseJSON['tweet_len'] < 300) {
          Alert('Unable to find more than 300 tweets from that Twitter account.\n\nThe AI will still work, but it may not work great!', context);
        }

        setState(() {
          ModelAccuracy = tweetResponseJSON['accuracy'] / 100;
          ProgressVisible = false;
          GenTweetListVisible = true;
          ButtonsEnabled = true;
          GamePageVisibilityLevel = 1;
        });

        int numTweets = tweetResponseJSON['gen_tweets'].length;
        for (int i = 0; i < numTweets; i++) {
          setState(() {
            GenTweetList[i] = tweetResponseJSON['gen_tweets'][i.toString()];
            RealTweetList[i] = tweetResponseJSON['actual_tweets'][i.toString()];
          });
        }

        CreateGameData();
      }
    }
  }

  // Set value of circular progress indicator to null (spinning) if it surpasses 100%
  GetValue(value) {
    if (value < 1.0) {
      return value;
    }
    else {
      return null;
    }
  }

  // Set text in center of circular progress indicator
  GetProgressPercent(value) {
    if (value < 1.0) {
      return (value * 100.0).round().toString() + '%';
    }
    else {
      return 'Generating\nTweets...';
    }
  }

  // Change slider color based on accuracy
  GetSliderColor() {
    if (ModelAccuracy < 0.20 || ModelAccuracy > 0.95) {
      return AlwaysStoppedAnimation(Colors.red[800]);
    }
    else if (ModelAccuracy < 0.35 || ModelAccuracy > 0.9) {
      return AlwaysStoppedAnimation(Colors.yellow[600]);
    }
    else {
      return AlwaysStoppedAnimation(Colors.lightBlue[700]);
    }
  }

  // Change accuracy text to the accuracy or N/A depending on whether AI has trained or not
  GetAccuracyText() {
    if (ModelAccuracy > 0.0) {
      return (ModelAccuracy * 100).round().toString() + '%';
    } else {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container (
      padding: EdgeInsets.all(10.0),
      child: Column (
        children: [
          Row (
            children: [
              // Username input field
              Expanded (
                child: TextField (
                  cursorColor: ActiveColor,
                  controller: UsernameController,
                  style: TextStyle (
                    fontSize: 14.0,
                    color: TextColor,
                  ),
                  decoration: InputDecoration (
                    prefixText: '@',
                    hintText: 'kanyewest',
                    labelText: 'Username',
                    labelStyle: TextStyle (
                      color: TextColor,
                    ),
                    hintStyle: TextStyle (
                      color: TextColor,
                    ),
                    isDense: true,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide (
                        color: ActiveColor,
                        width: 2.0,
                      ),
                    ),
                    border: OutlineInputBorder (
                      borderSide: BorderSide (
                        color: ActiveColor,
                        width: 2.0,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder (
                      borderSide: BorderSide (
                        color: ActiveColor,
                        width: 2.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder (
                      borderSide: BorderSide (
                        color: ActiveColor,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
              // Training time slider and accompanying text
              Expanded (
                child: Stack (
                  children: [
                    Center (
                      child: Container (
                        margin: EdgeInsets.fromLTRB(0.0, 13.0, 0.0, 0.0),
                        child: Text (
                          'AI Training Time (Min)',
                          style: TextStyle(
                            color: TextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                    Container (
                      margin: EdgeInsets.fromLTRB(0.0, 11.0, 0.0, 0.0),
                      child: SliderTheme (
                        data: SliderThemeData (
                          thumbColor: ActiveColor,
                          activeTrackColor: ActiveColor,
                          inactiveTrackColor: TextColor,
                          trackHeight: 8.0,
                          activeTickMarkColor: ActiveColor,
                          inactiveTickMarkColor: TextColor,
                        ),
                        child: Slider (
                          value: sliderVal,
                          onChanged: (newRating) {
                            setState(() {
                              sliderVal = newRating;
                            });
                          },
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: sliderVal.toString(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container (
            margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Submit button
                Container (
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                  width: 100.0,
                  child: OutlinedButton (
                    onPressed: ButtonsEnabled
                      ? () => SubmitPress()
                      : null,
                    child: Text (
                      'Submit',
                      style: TextStyle (
                        color: TextColor,
                      ),
                    ), 
                    style: ButtonStyle (
                      side: MaterialStateProperty.all(
                        BorderSide (
                          color: ActiveColor,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                // Accuracy bar
                Expanded (
                  child: Container (
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Stack (
                      children: [
                        Column (
                          children: [
                            ClipRRect (
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),   
                              child: LinearProgressIndicator (
                                valueColor: GetSliderColor(),
                                backgroundColor: TextColor,
                                value: ModelAccuracy,
                                minHeight: 18.0,
                              ),
                            ),
                            Container (
                              margin: EdgeInsets.fromLTRB(0.0, 2.0, 0.0, 0.0),
                              child: Center (
                                child: Tooltip (
                                  padding: EdgeInsets.all(10.0),
                                  margin: EdgeInsets.symmetric(horizontal: 15.0),
                                  waitDuration: Duration(milliseconds: 50),
                                  showDuration: Duration(seconds: 10),
                                  decoration: BoxDecoration(
                                    color: DarkBG,
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  message: "The AI accuracy measures how well the AI performed during training. A range of 40% to 70% is ideal. You'll be shown the accuracy after training finishes.\n\nIf the accuracy is too low, the results may not make sense. Too high, and the AI might generate tweets similar to some that already exist!",
                                  textStyle: TextStyle (
                                    fontSize: 13.0,
                                    color: TextColor,
                                  ),
                                  child: Text (
                                    'AI Accuracy',
                                    style: TextStyle (
                                      decoration: TextDecoration.underline,
                                      fontSize: 11.0,
                                      color: ActiveColor,
                                    ),
                                  ),
                                )
                              ),
                            ),
                          ],
                        ),
                        Container (
                          margin: EdgeInsets.only(right: 5.0),
                          height: 18.0,
                          child: Align (
                            alignment: Alignment.centerRight,
                            child: Text (
                              GetAccuracyText(),
                              style: TextStyle (
                                fontSize: 12.5,
                                color: DarkBG,
                              ),
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded (
            child: Column (
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Generated tweet list
                Visibility (
                  visible: GenTweetListVisible,
                  child: Expanded (
                    child: Container (
                      padding: EdgeInsets.all(10.0),
                      margin: EdgeInsets.only(bottom: 3.0),
                      decoration: BoxDecoration (
                        color: LightBG,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: RawScrollbar (
                        thumbColor: TextColor,
                        radius: Radius.circular(5.0),
                        isAlwaysShown: true,
                        child: ScrollConfiguration (
                          behavior: RemoveGlow(),
                          child: ListView (
                            children: [
                              for(String tweet in GenTweetList.sublist(10))
                              Container (
                                padding: EdgeInsets.symmetric(vertical: 18.0, horizontal: 8.0),
                                child: SelectableText (
                                  tweet,
                                  style: TextStyle (
                                    color: TextColor,
                                    fontSize: 17.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Circular loading indicator
                Visibility (
                  visible: ProgressVisible,
                  child: TweenAnimationBuilder (
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(minutes: ProgressTime),
                    builder: (context, double value, _) => Stack (
                      children: [
                        SizedBox (
                          height: 250.0,
                          width: 250.0,
                          child: CircularProgressIndicator (
                            value: GetValue(value),
                            color: ActiveColor,
                            backgroundColor: TextColor,
                            strokeWidth: 15.0,
                          ),
                        ),
                        SizedBox (
                          width: 250.0,
                          height: 250.0,
                          child: Center(child: 
                            Text (
                              GetProgressPercent(value),
                              style: TextStyle (
                                color: TextColor,
                                fontSize: 24.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align (
                  alignment: Alignment.center,
                  // Circular loading placeholder (just a gray circle)
                  child: Visibility (
                    visible: ProgressPlaceHolderVisible,
                    child: SizedBox (
                      height: 250.0,
                      width: 250.0,
                      child: CircularProgressIndicator (
                        value: 0.0,
                        backgroundColor: TextColor,
                        strokeWidth: 15.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// -- GAME PAGE --


class Game extends StatefulWidget {
  const Game({ Key? key }) : super(key: key);

  @override
  _GameState createState() => _GameState();
}

class _GameState extends State<Game> {
  var GameButtonColors = [LightBG, LightBG, LightBG, LightBG];
  bool IsAnswerPressed = false;

  // Figure out which page should be visible
  GetGamePageVisibility(int level) {
    if (level == GamePageVisibilityLevel) {
      return true;
    }
    else {
      return false;
    }
  }

  // Figure out which question should be visible
  GetGameQuestionVisibility(int question) {
    if (question == CurrentQuestion) {
      return true;
    }
    else {
      return false;
    }
  }

  // Handle pressing an answer in the game
  GameAnswerPressed(int AnswerPressed) {
    if (IsAnswerPressed == false) {
      IsAnswerPressed = true;
      if (AnswerPressed == GameAnswerList[CurrentQuestion]) {
        NumQuestionCorrect++;
      }
      else {
        setState(() {
          GameButtonColors[AnswerPressed] = Colors.red;
        });
      }
      setState(() {
        GameButtonColors[GameAnswerList[CurrentQuestion]] = Colors.green;
      });

      Future.delayed(Duration(seconds: 1), (){
        setState(() {
          GameButtonColors = [LightBG, LightBG, LightBG, LightBG];
          CurrentQuestion ++;
          if (CurrentQuestion == 10) {
            GamePageVisibilityLevel = 2;
          }
          IsAnswerPressed = false;
        });
      });
    }
  }

  // Show instruction sheet at bottom of page
  ShowBottomSheet(context) {
    showModalBottomSheet (
      shape: RoundedRectangleBorder (
        borderRadius: BorderRadius.circular(10.0),
      ),
      backgroundColor: MedBG,
      context: context,
      builder: (BuildContext context) {
        return Container (
          padding: EdgeInsets.all(25.0),
          child: Column (
            mainAxisSize: MainAxisSize.min,
            children: [
              Container (
                margin: EdgeInsets.only(bottom: 15.0),
                child: Text (
                  'How to Play',
                  style: TextStyle (
                    color: ActiveColor,
                    fontSize: 25.0,
                  )
                ),
              ),
              Text (
                "Before playing, you have to train an AI from the home page.\n\nAfter training the AI, you can come back here and see how good you are at discerning fake tweets from real ones! You'll be given three real tweets and one generated by the AI, and it's your job to pick the AI generated one. After ten questions, you'll get your final score.",
                style: TextStyle (
                  color: TextColor,
                  fontSize: 18.0,
                  height: 1.3,
                ),
              )
            ]
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container (
      padding: EdgeInsets.all(20.0),
      child: Column (
        children: [
          Visibility (
            // Instruction page (before AI has trained)
            visible: GetGamePageVisibility(0),
            child: Center (
              child: Column (
                children: [
                  Text (
                    'You have to train an AI from the home page to play the game!',
                    textAlign: TextAlign.center,
                    style: TextStyle (
                      color: TextColor,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  Container (
                    margin: EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 0.0),
                    child: OutlinedButton (
                      onPressed: () {ShowBottomSheet(context);},
                      child: Text (
                        'How to play',
                        style: TextStyle (
                            color: TextColor,
                        ),
                      ), 
                      style: ButtonStyle (
                        side: MaterialStateProperty.all(
                          BorderSide (
                            color: ActiveColor,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          // Show questions
          Visibility (
            visible: GetGamePageVisibility(1),
            child: Expanded (
              child: Column (
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text (
                    'Choose the AI Generated Tweet',
                    textAlign: TextAlign.center,
                    style: TextStyle (
                      fontSize: 25.0,
                      color: ActiveColor,
                    ),
                  ),
                  for (int i = 0; i < 10; i++)
                  Container (
                    child: Visibility (
                      visible: GetGameQuestionVisibility(i),
                      child: Container (
                        margin: EdgeInsets.only(top: 15.0),
                        child: Column (
                          children: [
                            for(int j = 0; j < 4; j++)
                            Container (
                              margin: EdgeInsets.symmetric(vertical: 10.0),
                              width: double.infinity,
                              height: 75.0,
                              child: OutlinedButton (
                                onPressed: () => GameAnswerPressed(j),
                                child: AutoSizeText (
                                  GameQuestionList[i * 4 + j],
                                  textAlign: TextAlign.center,
                                  style: TextStyle (
                                    color: TextColor,
                                    fontSize: 17.0,
                                  ),
                                ),
                                style: ButtonStyle (
                                  shape: MaterialStateProperty.all<RoundedRectangleBorder> (
                                    RoundedRectangleBorder (
                                      borderRadius: BorderRadius.circular(8.0),
                                    )
                                  ),
                                  padding: MaterialStateProperty.all(EdgeInsets.all(10.0)),
                                  backgroundColor: MaterialStateProperty.all(LightBG),
                                  side: MaterialStateProperty.all(
                                    BorderSide (
                                      color: GameButtonColors[j],
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded (
                    child: Align (
                      alignment: Alignment.bottomCenter,
                      child: Text (
                        'Question ${CurrentQuestion + 1} / 10',
                        style: TextStyle (
                          fontSize: 20.0,
                          color: TextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show score after game has finished
          Visibility (
            visible: GetGamePageVisibility(2),
            child: Expanded (
              child: Column (
                mainAxisSize: MainAxisSize.max,
                children: [
                  Center (
                    child: Container (
                      margin: EdgeInsets.only(top: 4.0),
                      child: Text (
                        'Final Score:\n${NumQuestionCorrect} / 10',
                        textAlign: TextAlign.center,
                        style: TextStyle (
                          color: ActiveColor,
                          fontSize: 35.0
                        )
                      ),
                    ),
                  ),
                  Expanded (
                    child: Align (
                      alignment: Alignment.bottomCenter,
                      child: Text (
                        'Train the AI to play again!',
                        textAlign: TextAlign.center,
                        style: TextStyle (
                          color: TextColor,
                          fontSize: 20.0
                        )
                      ),
                    ),
                  ),
                ],
              ),
            )
          ),
        ],
      ),
    );
  }
}


// -- INFO PAGE --


class Info extends StatefulWidget {
  const Info({ Key? key }) : super(key: key);

  @override
  _InfoState createState() => _InfoState();
}

class _InfoState extends State<Info> {
  @override
  Widget build(BuildContext context) {
    return Container (
      padding: EdgeInsets.fromLTRB(20.0, 20.0, 7.0, 20.0),
      child: RawScrollbar (
        thumbColor: TextColor,
        radius: Radius.circular(5.0),
        isAlwaysShown: true,
        child: ScrollConfiguration (
          behavior: RemoveGlow(),
          child: ListView (
            padding: EdgeInsets.fromLTRB(0.0, 0.0, 20.0, 0.0),
            children: [
              Container (
                margin: EdgeInsets.only(bottom: 4.0),
                child: Text (
                  'How to use',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: ActiveColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 34.0,
                  ),
                ),
              ),
              Text (
                "This app uses an AI to create tweets for you! The AI results are occasionally realistic, but mostly just funny. To use the app, enter a twitter username in the text box and adjust the slider depending on how long you want the AI to train in minutes. Then, click the submit button and wait for the AI to train using the Tweets. A longer training time will produce more accurate results. If the accuracy is too low, the results will be gibberish, but if it's too high, the AI might create tweets very similar to ones that already exist! Feel free to leave the app while it is training and come back later (as long as you don't fully close it).",
                textAlign: TextAlign.left,
                style: TextStyle (
                  color: TextColor,
                  fontSize: 16.0,
                  height: 1.4,
                ),
              ),
              Divider (
                color: DarkBG,
                height: 35.0,
                thickness: 2.0,
              ),
              Container (
                margin: EdgeInsets.only(bottom: 4.0),
                child: Text (
                  'How it works',
                  textAlign: TextAlign.left,
                  style: TextStyle (
                    color: ActiveColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 34.0,
                  ),
                ),
              ),
              Text (
                "To begin, the last 300 tweets from your selected Twitter user are grabbed from the internet and converted into a usable dataset for an LSTM neural network. This type of neural network is often used for language processing because of its ability to remember important information for long periods of time. After training the AI on the Tweets for however long you specify, the AI is used to generate a list of tweets.\n\nThe backend of this app was developed in Python using Tensorflow, the frontend was developed with Flutter and Dart, and the server that allows them to communicate was developed in Python using Flask. All of the Python code for the backend of this app can be found here:",
                textAlign: TextAlign.left,
                style: TextStyle (
                  color: TextColor,
                  fontSize: 16.0,
                  height: 1.4,
                ),
              ),
              SelectableText (
                'github.com/kkehe/TweetLSTM',
                textAlign: TextAlign.center,
                style: TextStyle (
                  color: TextColor,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  height: 2.5,
                ),
              ),
              Divider (
                color: DarkBG,
                height: 35.0,
                thickness: 2.0,
              ),
              Container (
                margin: EdgeInsets.only(bottom: 4.0),
                child: Text (
                  'About the developer',
                  textAlign: TextAlign.left,
                  style: TextStyle (
                    color: ActiveColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 34.0,
                  ),
                ),
              ),
              Text (
                "Hello, I'm Kayden! I'm currently a junior in high school, and I'm (as you can probably tell) interested in programming. I'm especially interested in deep learning; I always thought pattern recognition was so unique to life, and it's just fascinating to think that people have developed ways for computers to do it. And even though this project is kind of silly, I learned a lot and had a great time creating it, and I'm pretty proud of how it turned out. Thank you for supporting me by downloading my app!\n\nSpecial thanks to my sister Nikki, who created the color palette and designed the app icon.",
                textAlign: TextAlign.left,
                style: TextStyle (
                  color: TextColor,
                  fontSize: 16.0,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// -- ALERT WIDGET --


Alert(String message, BuildContext context) {
  showDialog (
    context: context,
    builder: (context) {
      return AlertDialog (
        backgroundColor: MedBG,
        content: Text(
          message,
          style: TextStyle(
            color: TextColor
          )
        ),
        actions: [
          TextButton(
            child: Text(
              'Okay',
              style: TextStyle(
                color: ActiveColor
              )
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }
  );
}


// -- PREVENT OVERSCROLL GLOW --


// https://stackoverflow.com/questions/51119795/how-to-remove-scroll-glow
class RemoveGlow extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
