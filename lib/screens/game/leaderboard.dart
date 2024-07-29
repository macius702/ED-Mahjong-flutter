import 'package:ed_mahjong/engine/highscore_storage.dart'
    show ScoreEntry, highscoreDB;
import 'package:ed_mahjong/preferences.dart' show MAX_LEADERBOARD_ENTRIES;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

class LeaderboardPage extends StatelessWidget {
  static const Route = '/leaderboard';
  final String board_layout;
  final String board_layout_display;
  final FocusNode _focusNode = FocusNode();

  LeaderboardPage({Key? key, required String board_layout})
      : board_layout = board_layout,
        board_layout_display =
            "${board_layout.split('.').first[0].toUpperCase()}${board_layout.split('.').first.substring(1)}", //take only before the dot

        super(key: key);
  @override
  Widget build(BuildContext context) {
    TextStyle getTextStyle() {
      return TextStyle(
        fontFamily: 'Anudaw',
        color: Colors.black,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      );
    }

    return KeyboardListener(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/backgrounds/scenic_bamboo_china.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                '$board_layout_display layout leaders',
                style: getTextStyle(),
              ),
              //backgroundColor: Colors.white,
            ),
            body: FutureBuilder<List<ScoreEntry>>(
              future: highscoreDB.getScoresByBoard(board_layout),
              builder: (BuildContext context,
                  AsyncSnapshot<List<ScoreEntry>> snapshot) {
                if (snapshot.hasData) {
                  return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: <DataColumn>[
                            DataColumn(
                              label: Text(
                                'Rank',
                                style: getTextStyle(),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Username',
                                style: getTextStyle(),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Time (secs)',
                                style: getTextStyle(),
                              ),
                            ),
                          ],
                          rows: List<DataRow>.generate(
                            MAX_LEADERBOARD_ENTRIES,
                            (int index) => DataRow(
                              cells: <DataCell>[
                                DataCell(Text(
                                  '${index + 1}',
                                  style: getTextStyle(),
                                )),
                                DataCell(Text(
                                  _getData(snapshot, index, 'username'),
                                  style: getTextStyle(),
                                )),
                                DataCell(Text(
                                  index < (snapshot.data?.length ?? 0)
                                      ? _fomatToMinSec(int.parse(
                                          _getData(snapshot, index, 'score')))
                                      : '',
                                  style: getTextStyle(),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ));
                } else if (snapshot.hasError) {
                  return Text(
                    'Error: ${snapshot.error}',
                    style: getTextStyle(),
                  );
                } else {
                  return CircularProgressIndicator();
                }
              },
            ),
          ),
        ));
  }
}

String _fomatToMinSec(int score) {
  Duration duration = Duration(milliseconds: score);
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitsFraction(int n) =>
      n.toString().padLeft(2, "0").substring(0, 2);
  return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}.${twoDigitsFraction(duration.inMilliseconds.remainder(1000) ~/ 10)}";
}

String _getData(
    AsyncSnapshot<List<ScoreEntry>> snapshot, int index, String key) {
  if (index >= (snapshot.data?.length ?? 0)) {
    return '';
  }

  var entry = snapshot.data?[index];

  switch (key) {
    case 'username':
      return entry?.username ?? '';
    case 'score':
      return entry?.score.toString() ?? '';
    default:
      return '';
  }
}
