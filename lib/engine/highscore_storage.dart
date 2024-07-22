import 'dart:async';

import 'package:agent_dart/agent_dart.dart';

import 'db_implementations/ICP/ICP_Connector.dart';

import 'db_implementations/ICP/config.dart' show backendCanisterId, Mode, mode;

abstract class IHighscoreDB {
  Future<Map<String, int>> getTimes();
  Future<void> set(String layout, int time);
}

class CandidHighscoreDB extends IHighscoreDB {
  final ICPconnector icpConnector;

  CandidHighscoreDB(this.icpConnector);

  get actor => icpConnector.actor;

  @override
  Future<Map<String, int>> getTimes() async {
    print("Calling CandidHighscoreDB.set: getTimes ...");

    var result = await callActorMethod<List<dynamic>>(CounterMethod.get_times);
    if (result != null) {
      Map<String, int> times = {};
      for (var item in result) {
        times[item[0]] = item[1];
      }
      print("CandidHighscoreDB.set: getTimes result: $times");
      return times;
    } else {
      print("CandidHighscoreDB.set: getTimes failed: Cannot get times");
      throw Exception("Cannot get times");
    }
  }

  @override
  Future<void> set(String layout, int time) async {
    print(
        "CandidHighscoreDB.set: Calling set with layout: $layout and time: $time");

    //callActorMethod with set_time
    await callActorMethod(CounterMethod.set_time, [layout, time]);

    print(
        "CandidHighscoreDB.set: Finished calling set. Now calling callbacks...");

    for (var callback in callbacks) {
      callback();
    }

    print("CandidHighscoreDB.set: Finished calling callbacks.");
  }

  List<Function()> callbacks = [];
  @override
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

abstract class CounterMethod {
  static const get_times = "get_times";
  static const set_time = "set_time";

  /// you can copy/paste from .dfx/local/canisters/counter/counter.did.js
  static final ServiceClass idl = IDL.Service({
    CounterMethod.get_times: IDL.Func(
      [],
      [
        IDL.Vec(IDL.Tuple([IDL.Text, IDL.Nat64]))
      ], // Pass the types as a list
      ['query'],
    ),
    CounterMethod.set_time: IDL.Func([IDL.Text, IDL.Nat64], [], []),
  });
}

late CandidHighscoreDB highscoreDB;
