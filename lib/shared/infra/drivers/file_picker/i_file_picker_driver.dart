import 'dart:io';

abstract interface class IFilePickerDriver {
  Future<File?> pickFile({required List<String>? allowedExtensions});

  /// Arquivo selecionado pelo picker Android que sobreviveu à recriação do
  /// processo/Activity. Em desktop sempre retorna null.
  Future<File?> findPendingFile();

  /// Confirma que o arquivo pendente já foi processado com sucesso (ou deve ser
  /// descartado). No Android remove a referência nativa e o arquivo temporário.
  Future<void> acknowledgePendingFile(File file);
}
