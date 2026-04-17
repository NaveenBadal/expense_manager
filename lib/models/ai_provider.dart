enum AiProviderType { localOnnx }

const selectedAiProviderStorageKey = 'selected_ai_provider';

extension AiProviderTypeX on AiProviderType {
  String get id => 'local_onnx';
  String get displayName => 'DistilBERT';
  String get modelStorageKey => 'model_local_onnx';
}

AiProviderType aiProviderFromId(String? raw) => AiProviderType.localOnnx;

String defaultModelFor(AiProviderType provider) => 'bundled_distilbert';
