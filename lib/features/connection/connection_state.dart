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
  const ConnectionConnected({required this.serverName});
}

class ConnectionError extends ConnectionUiState {
  final String message;
  const ConnectionError(this.message);
}
