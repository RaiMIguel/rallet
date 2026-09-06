abstract interface class IRestoreBackup {
  /// Retorna true somente quando um arquivo foi selecionado e restaurado.
  /// Retorna false quando o seletor é cancelado.
  Future<bool> restore();
}
