import '../../core_abstraction/connection_session.dart';

sealed class ConnectionUiState {
  const ConnectionUiState();
}

class ConnectionIdle extends ConnectionUiState {
  const ConnectionIdle();
}

class ConnectionConnecting extends ConnectionUiState {
  const ConnectionConnecting();
}

class ConnectionConnected extends ConnectionUiState {
  final String leafId;
  final String serverName;
  final DateTime connectedAt;
  final ConnectionMode mode;
  const ConnectionConnected({
    required this.leafId,
    required this.serverName,
    required this.connectedAt,
    required this.mode,
  });
}

class ConnectionStopping extends ConnectionUiState {
  const ConnectionStopping();
}

class ConnectionError extends ConnectionUiState {
  final String message;
  const ConnectionError(this.message);
}
