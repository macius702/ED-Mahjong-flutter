

import 'package:ed_mahjong/engine/highscore_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardPage extends StatelessWidget {
  static const Route = '/leaderboard';
  final String board_setup;
  final String board_setup_display;
  LeaderboardPage({Key? key, required String board_setup})
      : board_setup = board_setup,
        board_setup_display =
            board_setup.split('.').first, //take only before the dot
        super(key: key);

  @override
  Widget build(BuildContext context) {
    TextStyle getTextStyle() {
      ////maShanZheng
      ///eduVicWaNtBeginner
      /////sevillana - no
      ///bodoniModa - no
      ///pacifico
      //majorMonoDisplay
      //zhiMangXing
      //longCang
      // zcoolQingKeHuangYou - no
      // rubikWetPaint
      return GoogleFonts.rubikWetPaint(
        fontSize: 32,
        color: Colors.black,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leaderboard of $board_setup_display',
          style: getTextStyle(),
        ),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ScoreEntry>>(
        future: highscoreDB.getTimesByBoard(board_setup),
        builder:
            (BuildContext context, AsyncSnapshot<List<ScoreEntry>> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
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
                    color: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected))
                        return Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(1);
                      if (index.isOdd) {
                        return Colors.white.withOpacity(1);
                      }
                      return null;
                    }),
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
                        ((snapshot.data?[index].score ?? 0) / 1000)
                            .toStringAsFixed(2),
                        style: getTextStyle(),
                      )),
                    ],
                  ),
                ),
              ),
            );
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
    );
  }
}
