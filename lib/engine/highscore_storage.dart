import 'dart:async';

import 'package:agent_dart/agent_dart.dart';

import 'db_implementations/ICP/ICP_Connector.dart';

class ScoreEntry {
  final String username;
  final int score;

  ScoreEntry({required this.username, required this.score});
}

abstract class IHighscoreDB {
  Future<Map<String, int>> getTimes();
  Future<void> set(String layout, int time, String user);
  Future<List<ScoreEntry>> getTimesByBoard(String layout);
}

class CandidHighscoreDB extends IHighscoreDB {
  final ICPconnector icpConnector;

  CandidHighscoreDB(this.icpConnector);

  get actor => icpConnector.actor;

  @override
  Future<Map<String, int>> getTimes() async {
    print("Calling CandidHighscoreDB.set: getTimes ...");

    var result = await callActorMethod<List<dynamic>>(BackendMethod.get_times);
    if (result != null) {
      print("HighscoreStorage: Result is not null. Processing items...");
      Map<String, int> times = {};
      for (var item in result) {
        print(
            "HighscoreStorage: Processing item with key ${item[0]} and value ${item[1]}");
        times[item[0]] = item[1];
        print("HighscoreStorage: Added item to times map.");
      }
      print(
          "HighscoreStorage: Finished processing items. Returning times map.");

      print("CandidHighscoreDB.getTimes: result: $times");
      return times;
    } else {
      print("CandidHighscoreDB.getTimes: failed: Cannot get times");
      throw Exception("Cannot get times");
    }
  }

  @override
  Future<List<ScoreEntry>> getTimesByBoard(String layout) async {
    print("Calling CandidHighscoreDB.set: getTimes ...");

    var r = await callActorMethod<Map<dynamic, dynamic>>(
        BackendMethod.get_times_by_board, [layout]);

    // result is record {scores: []}
    // result is one element Map
    // take the value of the signle element of result

    if (r == null) {
      print("1 CandidHighscoreDB.getTimes: failed: Cannot get times");
      throw Exception("Cannot get times");
    }

    var result = r['scores'];

    print("Result is $result");
    if (result != null) {
      print("HighscoreStorage: Result is not null. Processing items...");
      List<ScoreEntry> times = [];
      for (var item in result) {
        print('Type of result is ${item.runtimeType}');
        print('Type of result.entries is ${item.runtimeType}');
        print('type of item is ${item.runtimeType}');

        print(
            "HighscoreStorage: Processing item with key ${item[1]} and value ${item[0]}");
        times.add(ScoreEntry(username: item[1], score: item[0]));
        print("HighscoreStorage: Added item to times map.");
      }
      print(
          "HighscoreStorage: Finished processing items. Returning times map.");

      print("CandidHighscoreDB.getTimes: result: $times");
      return times;
    } else {
      print("CandidHighscoreDB.getTimes: failed: Cannot get times");
      throw Exception("Cannot get times");
    }
  }

  @override
  Future<void> set(String layout, int time, String user) async {
    print(
        "CandidHighscoreDB.set: Calling set with layout: $layout and time: $time");

    //callActorMethod with set_time
    await callActorMethod(BackendMethod.set_time, [layout, time, user]);

    print(
        "CandidHighscoreDB.set: Finished calling set. Now calling callbacks...");

    for (var callback in callbacks) {
      callback();
    }

    print("CandidHighscoreDB.set: Finished calling callbacks.");
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
      print("Function call result: $res");
      return res as T?;
    } else {
      print("getFunc returned null");
    }

    throw Exception("Cannot call method: $method");
  }
}

abstract class BackendMethod {
  static const get_times = "get_times";
  static const set_time = "set_time";
  static const get_times_by_board = "get_times_by_board";

  static final Leaderboard = IDL.Record({
    'scores': IDL.Vec(
        IDL.Tuple([IDL.Nat32, IDL.Text])), // mtlk todo - record not needed
  });

  /// you can copy/paste from .dfx/local/canisters/counter/counter.did.js
  static final ServiceClass idl = IDL.Service({
    BackendMethod.get_times: IDL.Func(
      [],
      [
        IDL.Vec(IDL.Tuple([IDL.Text, IDL.Nat32]))
      ],
      ['query'],
    ),
    BackendMethod.set_time: IDL.Func([IDL.Text, IDL.Nat32, IDL.Text], [], []),
    BackendMethod.get_times_by_board:
        IDL.Func([IDL.Text], [Leaderboard], ['query']),
  });
}

late CandidHighscoreDB highscoreDB;
