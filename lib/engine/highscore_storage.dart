import 'dart:async';

import 'package:ed_mahjong/engine/db_implementations/sembast.dart';


import 'package:agent_dart/agent_dart.dart';

import 'db_implementations/ICP/ICP_Connector.dart';

//./src/mahjong_icp_frontend/lib/engine/db_implementations/ICP/config.dart
import 'db_implementations/ICP/config.dart' show backendCanisterId, Mode, mode;


abstract class IHighscoreDB {
  Future<Map<String, int>> getTimes();
  Future<void> set(String layout, int time);
}




// GitHub Copilot: To implement the `IHighscoreDB` abstract class using Candid types in Dart, you would need to create a new class that extends `IHighscoreDB`. Candid is a language-agnostic interface description language (IDL) used in the Internet Computer ecosystem. However, Dart does not natively support Candid. 

// Here's an example of how you might implement the `IHighscoreDB` abstract class in Dart:

// ```dart
// import 'dart:async';

// class CandidHighscoreDB implements IHighscoreDB {
//   @override
//   Future<Map<String, int>> getTimes() async {
//     // Implement your method using Candid types here.
//     // As Dart does not natively support Candid, you would need to use a library or API that provides this functionality.
//   }

//   @override
//   Future<void> set(String layout, int time) async {
//     // Implement your method using Candid types here.
//     // As Dart does not natively support Candid, you would need to use a library or API that provides this functionality.
//   }
// }
// ```

// Please note that this is a basic example and does not include the actual implementation of the methods using Candid types. As Dart does not natively support Candid, you would need to use a library or API that provides this functionality.

// For your next steps, you might want to:
// - Find a library or API that allows you to use Candid types in Dart
// - Implement the `getTimes` and `set` methods using Candid types
// - Test your code to ensure it's working as expected
// - Continue working on your Dart project.



class CandidHighscoreDB extends IHighscoreDB {
  final ICPconnector icpConnector;

  CandidHighscoreDB._() : icpConnector = ICPconnector(canisterId: backendCanisterId, url: get_frontend_url(), newIdl: idl);

  static final CandidHighscoreDB instance = CandidHighscoreDB._();


  CandidHighscoreDB(this.icpConnector);

  get actor => icpConnector.actor;

  @override
  Future<Map<String, int>> getTimes() async {

  //now call actor method with get_times
    var result = await callActorMethod<List<dynamic>>(get_times);
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
  Future<void> set(String layout, int time) async {

    //mtlk todo - already loading ??
    // Implement your method using Candid types here.
    // As Dart does not natively support Candid, you would need to use a library or API that provides this functionality.

    //callActorMethod with set_time
    await callActorMethod(set_time, [layout, time]);

    for (var callback in callbacks) {
      callback();
    }


  }

  List<Function()> callbacks = [];
  onChange(Function() change) {
    callbacks.add(change);
  }




  Future<T?> callActorMethod<T>(String method, [List<dynamic> params = const []]) async {
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


  /// use staic const as method name
  static const get_times = "get_times";
  static const set_time = "set_time";

  /// you can copy/paste from .dfx/local/canisters/counter/counter.did.js
  static final ServiceClass idl =  IDL.Service({
    'get_times' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple([IDL.Text, IDL.Nat64]))], // Pass the types as a list
        ['query'],
      ),
  
    'set_time' : IDL.Func([IDL.Text, IDL.Nat64], [], []),
  });

  
  
}


class HighscoreDB extends IHighscoreDB {
  HighscoreDB._();
  static final HighscoreDB instance = HighscoreDB._();

  IHighscoreDB get database {
    return HighscoreSembast.instance;
  }

  Map<String, int>? _times;
  Future<void>? _alreadyLoading;
  List<Function()> callbacks = [];

  Future<Map<String, int>> getTimes() async {
    Map<String, int>? _times = this._times;
    if (_times == null) {
      final futureBuilder = Completer<void>();
      this._alreadyLoading = futureBuilder.future;
      this._times = _times = await database.getTimes();
      this._alreadyLoading = null;
      futureBuilder.complete();
    }
    return _times;
  }

  Future<void> set(String layout, int time) async {
    if (_alreadyLoading != null) await _alreadyLoading;
    final _times = this._times;
    if (_times != null) {
      _times[layout] = time;
    } else {
      this._times = {layout: time};
    }
    await database.set(layout, time);

    for (var callback in callbacks) {
      callback();
    }
  }

  onChange(Function() change) {
    callbacks.add(change);
  }
}

final highscoreDB = CandidHighscoreDB.instance;
