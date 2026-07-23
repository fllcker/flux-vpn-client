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
  final String serverName;
  final DateTime connectedAt;
  const ConnectionConnected({
    required this.serverName,
    required this.connectedAt,
  });
}

class ConnectionStopping extends ConnectionUiState {
  const ConnectionStopping();
}

class ConnectionError extends ConnectionUiState {
  final String message;
  const ConnectionError(this.message);
}
