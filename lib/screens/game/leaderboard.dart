import 'package:ed_mahjong/engine/highscore_storage.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  static const Route = '/leaderboard';
  final String board_setup;
  final String board_setup_display;
  LeaderboardPage({Key? key, required String board_setup})
      : board_setup = board_setup,
        board_setup_display =
            "${board_setup.split('.').first[0].toUpperCase()}${board_setup.split('.').first.substring(1)}", //take only before the dot

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

    return Container(
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
            '$board_setup_display layout leaders',
            style: getTextStyle(),
          ),
          //backgroundColor: Colors.white,
        ),
        body: FutureBuilder<List<ScoreEntry>>(
          future: highscoreDB.getTimesByBoard(board_setup),
          builder:
              (BuildContext context, AsyncSnapshot<List<ScoreEntry>> snapshot) {
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
                        snapshot.data?.length ?? 0,
                        (int index) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(
                              '${index + 1}',
                              style: getTextStyle(),
                            )),
                            DataCell(Text(
                              snapshot.data?[index].username ?? 'default',
                              style: getTextStyle(),
                            )),
                            DataCell(Text(
                              _fomatToMinSec(snapshot.data?[index].score ?? 0),
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
    );
  }
}

String _fomatToMinSec(int score) {
  Duration duration = Duration(milliseconds: score);
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitsFraction(int n) =>
      n.toString().padLeft(2, "0").substring(0, 2);
  return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}.${twoDigitsFraction(duration.inMilliseconds.remainder(1000) ~/ 10)}";
}
