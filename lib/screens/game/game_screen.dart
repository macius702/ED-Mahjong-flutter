import 'dart:ui';

import 'package:ed_mahjong/engine/backgrounds/background_meta.dart';
import 'package:ed_mahjong/engine/highscore_storage.dart'
    show ScoreEntry, highscoreDB;
import 'package:ed_mahjong/engine/layouts/layout.dart';
import 'package:ed_mahjong/engine/layouts/layout_meta.dart';
import 'package:ed_mahjong/engine/layouts/top_down_generator.dart';
import 'package:ed_mahjong/engine/pieces/game_board.dart';
import 'package:ed_mahjong/engine/pieces/mahjong_tile.dart';
import 'package:ed_mahjong/engine/tileset/tileset_flutter.dart';
import 'package:ed_mahjong/engine/tileset/tileset_meta.dart';
import 'package:ed_mahjong/preferences.dart';
import 'package:ed_mahjong/screens/game/history_drawer.dart';
import 'package:ed_mahjong/screens/game/leaderboard.dart';
import 'package:ed_mahjong/screens/game/menu_drawer.dart';
import 'package:ed_mahjong/screens/game/timer_text.dart';
import 'package:ed_mahjong/widgets/layout_preview.dart';
import 'package:ed_mahjong/widgets/tile_animation_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

import '../../widgets/board.dart';

import 'dart:async';

class GamePage extends StatefulWidget {
  static const Route = '/game';
  final String layout;

  static PageRoute<dynamic>? generateRoute(
      RouteSettings routeSettings, Uri uri) {
    var id =
        uri.pathSegments.length > 1 ? uri.pathSegments[1] : "default.desktop";
    return MaterialPageRoute(builder: (context) => GamePage(layout: id));
  }

  GamePage({Key? key, required this.layout}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameBoard? board;
  LayoutMeta? layoutMeta;
  TilesetMeta? tilesetMeta;
  List<HistoryState> history = [];
  bool ready = false;
  int? selectedX;
  int? selectedY;
  int? selectedZ;

  int? startAt;
  int shuffles = 0;
  int maxShuffles = -1;
  int shuffleId = 0;

  bool _isLoading = false;

  _GamePageState();

  @override
  initState() {
    super.initState();
    loadInit().catchError((error) {});
  }

  @override
  void didUpdateWidget(GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layout != oldWidget.layout) {
      setState(() {
        board = null;
        layoutMeta = null;
      });
      loadInit().catchError((error) {
        print(error);
      });
    }
  }

  Future<void> loadInit() async {
    final layoutMetas = await LayoutMetaCollection.load(this.context);
    final tilesetMetas = await loadTilesets(this.context);
    final layoutMeta = layoutMetas.get(widget.layout);
    final baseLayout = await layoutMeta.getLayout(this.context);
    final preferences = await Preferences.instance;
    final tileset = tilesetMetas.get(preferences.tileset);

    final layout = baseLayout.compress();

    final imgs = [
      "TILE_1",
      "TILE_1_SEL",
      ...MahjongTile.values.map((tile) => tileToString(tile))
    ];

    final base =
        'assets/tilesets/${basenameWithoutExtension(tileset.fileName)}';

    await Future.wait(imgs
        .map((s) => precacheImage(AssetImage('$base/$s.png'), this.context)));

    final precalc = layout.getPrecalc();
    GameBoard? b;
    try {
      b = makeBoard(layout, precalc);
    } catch (e) {
      await showLoosingDialog("The layout is impossible to solve");
      return;
    }

    setState(() {
      this.startAt = DateTime.now().millisecondsSinceEpoch;
      this.maxShuffles = preferences.maxShuffles;
      this.layoutMeta = layoutMeta;
      this.tilesetMeta = tileset;
      board = b;
    });
  }

  Future<void> shuffle() async {
    if (!canShuffle) {
      await showLoosingDialog("You don't have any shuffles left");
      return;
    }

    final board = this.board!;
    final layout = board.layout;

    List<MahjongTile> tileSupply = [];
    for (var layer in board.tiles) {
      for (var row in layer) {
        for (var tile in row) {
          if (tile == null) continue;
          tileSupply.add(tile);
        }
      }
    }

    var precalc = layout.getPrecalc();

    GameBoard newBoard;
    try {
      newBoard = makeBoard(layout, precalc, tileSupply);
    } catch (e) {
      await showLoosingDialog("The game has become unsolvable");
      return;
    }

    setState(() {
      this.shuffles++;
      this.shuffleId++;
      this.board = newBoard;
      this.history = [];
    });
  }

  showWinningDialog() async {
    final preferences = await Preferences.instance;

    // When developer option is on then add 59 mniutes to the time
    final addittionalFakeTime =
        preferences.developerShortenGame ? 59 * 60 * 1000 : 0;

    final finalTime = DateTime.now().millisecondsSinceEpoch -
        (this.startAt ?? 0) +
        addittionalFakeTime;

    final List<ScoreEntry> entries =
        await highscoreDB.getScoresByBoard(widget.layout);
    final isHighScore = entries.length < MAX_LEADERBOARD_ENTRIES ||
        finalTime < entries.last.score;
    final isBestScore = entries.length == 0 || finalTime < entries.first.score;
    final TextEditingController _controller = TextEditingController();

    String username = "";

    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: this.context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: false /* user must tap button! */,
      builder: (BuildContext context) {
        void handleFormSubmission() async {
          if (_formKey.currentState?.validate() ?? false) {
            _formKey.currentState?.save();
            // Store the username in session here, use hourglass (CircularProgressIndicator) to show loading

            if (isHighScore) {
              setState(() {
                this._isLoading = true;
              });

              await highscoreDB.setScore(widget.layout, finalTime, username);

              setState(() {
                this._isLoading = false;
              });

              Navigator.of(context).pop();
              Navigator.of(context).pop();

              //Navigate to /leaderboard
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LeaderboardPage(board_layout: widget.layout),
                ),
              );
            } else {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            }
          }
        }

        return AlertDialog(
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                isHighScore
                    ? Column(
                        children: <Widget>[
                          Text(
                            isBestScore
                                ? "Congratulations! You set a new best time: ${timeToString(finalTime)}"
                                : "Congratulations! You made it to the leaderboard with a time of ${timeToString(finalTime)}",
                          ),
                          TextFormField(
                            autofocus: true,
                            onFieldSubmitted: (value) => handleFormSubmission(),
                            controller: _controller,
                            decoration:
                                InputDecoration(hintText: 'Enter your name'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                            onSaved: (input) => username = input ?? "",
                          ),
                        ],
                      )
                    : Text("You won!"),
              ],
            ),
          ),
          actions: <Widget>[
            DebouncedButton(
              child: Text('Yay!'),
              onPressed: handleFormSubmission,
              debounceDuration: Duration(milliseconds: 10000),
            ),
          ],
        );
      },
    );
  }

  showLoosingDialog(String reason) async {
    showDialog(
      context: this.context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: false /* user must tap button! */,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text("You lost! $reason."),
          actions: <Widget>[
            TextButton(
                child: Text('Dang it!'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }),
          ],
        );
      },
    );
  }

  showShuffleDialog() async {
    showDialog(
      context: this.context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: false /* user must tap button! */,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text("No more available moves"),
          actions: <Widget>[
            TextButton(
                child: Text('Shuffle'),
                onPressed: () {
                  Navigator.of(context).pop();
                  shuffle();
                }),
          ],
        );
      },
    );
  }

  TileAnimationLayer? _tileAnimationLayer;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    final locale = PlatformDispatcher.instance.locale;
    final tilesetMeta = this.tilesetMeta;
    final layoutMeta = this.layoutMeta;

    TileAnimationLayer? tileAnimationLayer = this._tileAnimationLayer;
    if (layoutMeta != null &&
        tilesetMeta != null &&
        tileAnimationLayer == null) {
      this._tileAnimationLayer = tileAnimationLayer = TileAnimationLayer(
        tilesetMeta: tilesetMeta,
        depth: this.board!.depth,
      );
    }

    return Scaffold(
      drawer: MenuDrawer(
          canShuffle: canShuffle,
          layoutName: layoutMeta?.name.toLocaleString(locale),
          shuffle: shuffle),
      endDrawer: tilesetMeta == null
          ? null
          : HistoryDrawer(
              tilesetMeta: tilesetMeta,
              history: history,
              restore: restore,
            ),
      body: Stack(children: [
        renderBackground(Center(
            child: board == null
                ? (_isLoading
                    ? CircularProgressIndicator()
                    : Text("Loading..."))
                : // Layoutuilder : SizedBox : InteractiveViewer : Board
                // LayoutBuilder to grab constraints and put them to SizedBox
                LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      // double fontSize =
                      //     min(constraints.maxWidth, constraints.maxHeight) / 10;
                      return SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: InteractiveViewer(
                              //boundaryMargin: EdgeInsets.all(0.0),
                              minScale: 1,
                              maxScale: 2,
                              child: Board(
                                shuffleId: shuffleId,
                                board: board!,
                                meta: layoutMeta!,
                                selectedX: selectedX,
                                selectedY: selectedY,
                                selectedZ: selectedZ,
                                tileAnimationLayer: tileAnimationLayer!,
                                onSelected: (x, y, z) {
                                  final board = this.board!;
                                  final oldSelectedX = this.selectedX;
                                  final oldSelectedY = this.selectedY;
                                  final oldSelectedZ = this.selectedZ;

                                  if (x == oldSelectedX &&
                                      y == oldSelectedY &&
                                      z == oldSelectedZ) return;

                                  final coord = Coordinate(x, y, z);
                                  if (!board.movable.contains(coord)) return;

                                  if (oldSelectedX == null ||
                                      oldSelectedY == null ||
                                      oldSelectedZ == null) {
                                    setSelectedCoord(x, y, z);
                                    return;
                                  }

                                  final selected = board.tiles[oldSelectedZ]
                                      [oldSelectedY][oldSelectedX];
                                  final newTile = board.tiles[z][y][x];

                                  if (selected != null &&
                                      newTile != null &&
                                      tilesMatch(selected, newTile)) {
                                    setState(() {
                                      final oldCoord = Coordinate(oldSelectedX,
                                          oldSelectedY, oldSelectedZ);
                                      final newCoord = Coordinate(x, y, z);
                                      history.add(HistoryState(selected,
                                          oldCoord, newTile, newCoord));

                                      board.update((tiles) {
                                        tileAnimationLayer!.createAnimation(
                                            selected,
                                            oldCoord,
                                            getTileDirection(board, oldCoord));
                                        tileAnimationLayer.createAnimation(
                                            newTile,
                                            newCoord,
                                            getTileDirection(board, newCoord));
                                        tiles[oldSelectedZ][oldSelectedY]
                                            [oldSelectedX] = null;
                                        tiles[z][y][x] = null;
                                      });
                                    });

                                    checkIsBoardSolveable();
                                    setSelectedCoord(null, null, null);
                                  } else {
                                    setSelectedCoord(x, y, z);
                                  }
                                },
                              )));
                    },
                  ))),
        Positioned(
          top: 10,
          right: 50,
          child: TimerText(),
        ),
      ]),
      floatingActionButton: Builder(
          builder: (context) => Row(mainAxisSize: MainAxisSize.min, children: [
                FloatingActionButton(
                  heroTag: "menuBtn",
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  tooltip: 'Menu',
                  child: Icon(Icons.menu),
                ),
                Container(
                  width: 20,
                  height: 0,
                ),
                FloatingActionButton(
                  heroTag: "leaderboardBtn",
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LeaderboardPage(board_layout: widget.layout)));
                  },
                  tooltip: 'Leaderboard',
                  child: Icon(Icons.leaderboard),
                ),
                Container(
                  width: 20,
                  height: 0,
                ),
                FloatingActionButton(
                  heroTag: "historyBtn",
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  tooltip: 'History',
                  child: Icon(Icons.history),
                )
              ])),
    );
  }

  FlyDirection getTileDirection(GameBoard board, Coordinate coord) {
    if (coord.x < 2) return FlyDirection.Left;
    if (coord.x > board.width - 2) return FlyDirection.Right;
    final layer = board.tiles[coord.z];
    final precalc = board.precalc;
    final idx = precalc.coordToIdx(coord);

    for (var leftIdx in precalc.neighborsLeft[idx]) {
      final nCoord = precalc.idxToCoordinate(leftIdx);
      if (layer[nCoord.y][nCoord.x] != null) return FlyDirection.Right;
    }
    for (var rightIdx in precalc.neighborsRight[idx]) {
      final nCoord = precalc.idxToCoordinate(rightIdx);
      if (layer[nCoord.y][nCoord.x] != null) return FlyDirection.Left;
    }
    if (coord.x < board.width / 2) {
      return FlyDirection.Left;
    }
    return FlyDirection.Right;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Widget renderBackground(Widget body) {
    return Consumer2<Preferences?, BackgroundMetaCollection?>(builder: (context,
        Preferences? preferences,
        BackgroundMetaCollection? backgrounds,
        child) {
      if (preferences == null || backgrounds == null) return body;
      final background = preferences.background;
      if (background == null) return body;
      final meta = backgrounds.get(background);
      return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/backgrounds/${meta.fileName}"),
                repeat: ImageRepeat.repeat,
                fit: BoxFit.none),
          ),
          child: body);
    });
  }

  setSelectedCoord(int? x, int? y, int? z) {
    setState(() {
      this.selectedX = x;
      this.selectedY = y;
      this.selectedZ = z;
    });
  }

  checkIsBoardSolveable() async {
    final preferences = await Preferences.instance;
    if (preferences.developerShortenGame) {
      await showWinningDialog();
      return;
    }

    final board = this.board;
    if (board == null) return;

    final newMovables = board.movable;
    final Set<MahjongTile> tiles = {};
    bool movesLeft = false;

    for (var moveableCoord in newMovables) {
      final tile =
          board.tiles[moveableCoord.z][moveableCoord.y][moveableCoord.x]!;
      final normalizedTile = isSeason(tile)
          ? MahjongTile.SEASON_1
          : isFlower(tile)
              ? MahjongTile.FLOWER_1
              : tile;
      if (tiles.contains(normalizedTile)) {
        movesLeft = true;
        break;
      }
      tiles.add(normalizedTile);
    }

    if (!movesLeft) {
      final tiles = board.tiles;

      var empty = true;

      boardSearch:
      for (var layer in tiles) {
        for (var row in layer) {
          for (var tile in row) {
            if (tile != null) {
              empty = false;
              break boardSearch;
            }
          }
        }
      }

      if (empty) {
        await showWinningDialog();
      } else {
        await showShuffleDialog();
      }
    }
  }

  bool get canShuffle {
    if (maxShuffles == -1) return true;
    return shuffles < maxShuffles;
  }

  int get shuffleLeft {
    if (maxShuffles == -1) return -1;
    return maxShuffles - shuffles;
  }

  restore(HistoryState state) {
    var idx = history.indexOf(state);
    var historyStates = history.skip(idx).toList().reversed;

    if (idx == -1) return;

    setState(() {
      board!.update((tiles) {
        for (var state in historyStates) {
          tiles[state.tile1Coord.z][state.tile1Coord.y][state.tile1Coord.x] =
              state.tile1;
          tiles[state.tile2Coord.z][state.tile2Coord.y][state.tile2Coord.x] =
              state.tile2;
        }
      });
      this.history = this.history.take(idx).toList();
      this.shuffleId++;
    });
  }
}

//https://medium.com/codex/double-tap-trouble-conquering-multiple-tap-issues-in-flutter-ecf62cde32b1
// Double-Tap Trouble: Conquering Multiple Tap Issues in Flutter
// Debasmita Sarkar
// CodeX
// Debasmita Sarkar

// ·
// Follow

class DebouncedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Duration debounceDuration;

  DebouncedButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  _DebouncedButtonState createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _isProcessing = false;
  Timer? _debounceTimer;

  void _handleTap() {
    if (_isProcessing) return;

    _isProcessing = true;
    widget.onPressed();

    _debounceTimer = Timer(widget.debounceDuration, () {
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _handleTap,
      child: widget.child,
    );
  }
}