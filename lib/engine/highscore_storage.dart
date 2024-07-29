import 'dart:async';

import 'package:agent_dart/agent_dart.dart';

import 'db_implementations/ICP/ICP_Connector.dart';

class ScoreEntry {
  final String username;
  final int score;

  ScoreEntry({required this.username, required this.score});
}

abstract class IHighscoreDB {
  Future<Map<String, int>> getBestScoreForAllBoards();
  Future<void> setScore(String layout, int time, String user);
  Future<List<ScoreEntry>> getScoresByBoard(String layout);
}

class CandidHighscoreDB extends IHighscoreDB {
  final ICPconnector icpConnector;

  CandidHighscoreDB(this.icpConnector);

  get actor => icpConnector.actor;

  @override
  Future<Map<String, int>> getBestScoreForAllBoards() async {
    var result = await callActorMethod<List<dynamic>>(
        BackendMethod.get_best_scores_for_all_boards);
    if (result != null) {
      Map<String, int> times = {};
      for (var item in result) {
        times[item[0]] = item[1];
      }

      return times;
    } else {
      throw Exception("Cannot get times");
    }
  }

  @override
  Future<List<ScoreEntry>> getScoresByBoard(String layout) async {
    var r = await callActorMethod<Map<dynamic, dynamic>>(
        BackendMethod.get_scores_by_board, [layout]);

    // result is record {scores: []}
    // result is one element Map
    // take the value of the signle element of result

    if (r == null) {
      throw Exception("Cannot get times");
    }

    var result = r['scores'];

    if (result != null) {
      List<ScoreEntry> times = [];
      for (var item in result) {
        times.add(
            ScoreEntry(username: item['user'], score: item['miliseconds']));
      }

      return times;
    } else {
      throw Exception("Cannot get times");
    }
  }

  @override
  Future<void> setScore(String layout, int time, String user) async {
    //callActorMethod with set_score
    await callActorMethod(BackendMethod.set_score, [layout, time, user]);

    for (var callback in callbacks) {
      callback();
    }
  }

  List<Function()> callbacks = [];

  onChange(Function() change) {
    callbacks.add(change);
  }

  Future<T?> callActorMethod<T>(String method,
      [List<dynamic> params = const []]) async {
    if (actor == null) {
      throw Exception("Actor is null");
    }

    ActorMethod? func = actor?.getFunc(method);
    if (func != null) {
      var res = await func(params);
      return res as T?;
    }

    throw Exception("Cannot call method: $method");
  }
}

abstract class BackendMethod {
  static const get_best_scores_for_all_boards =
      "get_best_scores_for_all_boards";
  static const set_score = "set_score";
  static const get_scores_by_board = "get_scores_by_board";

  static final Score = IDL.Record({'user': IDL.Text, 'miliseconds': IDL.Nat32});
  static final Leaderboard = IDL.Record({'scores': IDL.Vec(Score)});

  /// you can copy/paste from .dfx/local/canisters/counter/counter.did.js
  static final ServiceClass idl = IDL.Service({
    BackendMethod.get_best_scores_for_all_boards: IDL.Func(
      [],
      [
        IDL.Vec(IDL.Tuple([IDL.Text, IDL.Nat32]))
      ],
      ['query'],
    ),
    BackendMethod.set_score: IDL.Func([IDL.Text, IDL.Nat32, IDL.Text], [], []),
    BackendMethod.get_scores_by_board:
        IDL.Func([IDL.Text], [Leaderboard], ['query']),
  });
}

late CandidHighscoreDB highscoreDB;
