// ignore_for_file: unused_import
// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'package:agent_dart/agent_dart.dart';
import 'config.dart' show backendCanisterId, Mode, mode;
import 'package:flutter/foundation.dart' show kIsWeb;



class ICPconnector {
  /// AgentFactory is a factory method that creates Actor automatically.
  /// Save your strength, just use this template
  AgentFactory? _agentFactory;

  /// CanisterCator is the actor that make all the request to Smartcontract.
  CanisterActor? get actor => _agentFactory?.actor;
  final String canisterId;
  final String url;

  ICPconnector({required this.canisterId, required this.url, ServiceClass? newIdl}) {
  }
  // A future method because we need debug mode works for local developement
  Future<void> setAgent(
      {String? newCanisterId, ServiceClass? newIdl, String? newUrl, Identity? newIdentity, bool? debug}) async {

    try {
      // Your network request code here

      _agentFactory ??= await AgentFactory.createAgent(
          canisterId: newCanisterId ?? canisterId,
          url: newUrl ?? url,
          idl: newIdl ?? IDL.Service({}),
          identity: newIdentity,
          debug: debug ?? true);

    } catch (e) {
      if (e is SocketException) {
        print('Cannot connect to the server. Please check your internet connection and server status.');
        print('Exception: $e');
      } else {
        // Re-throw the exception for further handling
        rethrow;
      }
    }
  }

  static Future<ICPconnector> init({Identity? identity, ServiceClass? newIdl}) async {
    ICPconnector icpConnector = ICPconnector(
        canisterId: backendCanisterId,
        url: get_frontend_url(), // set agent when other paramater comes in like new Identity
        newIdl: newIdl);

    await icpConnector.setAgent(newIdentity: identity, newIdl: newIdl);
    return icpConnector;
  }

  static Uri createUri(String path) {
    return Uri.parse('${get_frontend_url()}$path?canisterId=$backendCanisterId');
  }
}

String frontend_url = '';

String get_frontend_url() {
  return 
      mode == Mode.playground
      ? 'https://icp-api.io'
      : mode == Mode.local
          ? kIsWeb
              ? 'http://127.0.0.1:4943'
              : 'http://10.0.2.2:4943' // for android emulator
          : 'https://icp-api.io'; // for Mode.network
}
