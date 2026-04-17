import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxInferenceResult {
  const OnnxInferenceResult({required this.label, this.merchant});
  final String label;
  final String? merchant;
}

class OnnxSmsService {
  OnnxSmsService._();
  static final OnnxSmsService instance = OnnxSmsService._();

  OrtSession? _session;
  Map<String, int>? _vocab;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  static const _clsId = 101;
  static const _sepId = 102;
  static const _padId = 0;
  static const _unkId = 100;
  static const _maxLen = 128;

  static const _id2label = {
    0: 'balance_info',
    1: 'bill_reminder',
    2: 'expense',
    3: 'income',
    4: 'otp',
    5: 'promotional',
    6: 'transfer',
  };

  static const _id2tag = {
    0: 'O',
    1: 'B-ACCOUNT',
    2: 'B-AMOUNT',
    3: 'B-BALANCE',
    4: 'B-DATE',
    5: 'B-MERCHANT',
    6: 'I-DATE',
    7: 'I-MERCHANT',
  };

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      OrtEnv.instance.init();

      final vocabText = await rootBundle.loadString('assets/onnx_model/vocab.txt');
      _vocab = <String, int>{};
      var idx = 0;
      for (final line in vocabText.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty) _vocab![t] = idx;
        idx++;
      }

      final modelData = await rootBundle.load('assets/onnx_model/model.onnx');
      final modelBytes = modelData.buffer.asUint8List();
      final opts = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, opts);
      opts.release();

      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      final c = _initCompleter!;
      _initCompleter = null;
      c.completeError(e);
      rethrow;
    }
  }

  bool _isWhitespace(int r) =>
      r == 32 || r == 9 || r == 10 || r == 13;

  bool _isPunct(int r) =>
      (r >= 33 && r <= 47) ||
      (r >= 58 && r <= 64) ||
      (r >= 91 && r <= 96) ||
      (r >= 123 && r <= 126);

  List<String> _basicTokenize(String text) {
    final result = <String>[];
    final buf = StringBuffer();
    for (final r in text.runes) {
      if (_isWhitespace(r)) {
        if (buf.isNotEmpty) {
          result.add(buf.toString());
          buf.clear();
        }
      } else if (_isPunct(r)) {
        if (buf.isNotEmpty) {
          result.add(buf.toString());
          buf.clear();
        }
        result.add(String.fromCharCode(r));
      } else {
        buf.writeCharCode(r);
      }
    }
    if (buf.isNotEmpty) result.add(buf.toString());
    return result;
  }

  List<String> _wordpiece(String word) {
    if (word.length > 200) return ['[UNK]'];
    final vocab = _vocab!;
    final subs = <String>[];
    var start = 0;
    while (start < word.length) {
      var end = word.length;
      String? found;
      while (start < end) {
        final s = start == 0
            ? word.substring(0, end)
            : '##${word.substring(start, end)}';
        if (vocab.containsKey(s)) {
          found = s;
          break;
        }
        end--;
      }
      if (found == null) return ['[UNK]'];
      subs.add(found);
      start = end;
    }
    return subs;
  }

  // Returns (tokenIds, tokenStrings) with [CLS] at [0] and [SEP] at end
  (List<int>, List<String>) _tokenize(String text) {
    final vocab = _vocab!;
    final lower = text.toLowerCase();
    final words = _basicTokenize(lower);
    final ids = <int>[_clsId];
    final strs = <String>['[CLS]'];

    for (final word in words) {
      for (final sub in _wordpiece(word)) {
        ids.add(vocab[sub] ?? _unkId);
        strs.add(sub);
      }
    }
    ids.add(_sepId);
    strs.add('[SEP]');

    if (ids.length > _maxLen) {
      ids.replaceRange(_maxLen - 1, ids.length, [_sepId]);
      strs.replaceRange(_maxLen - 1, strs.length, ['[SEP]']);
    }
    return (ids, strs);
  }

  Future<OnnxInferenceResult> infer(String smsText) async {
    await ensureInitialized();
    final (tokenIds, tokenStrs) = _tokenize(smsText);

    final inputIds = Int64List(_maxLen);
    final attMask = Int64List(_maxLen);
    for (var i = 0; i < _maxLen; i++) {
      inputIds[i] = i < tokenIds.length ? tokenIds[i] : _padId;
      attMask[i] = i < tokenIds.length ? 1 : 0;
    }

    final inTensor =
        OrtValueTensor.createTensorWithDataList(inputIds, [1, _maxLen]);
    final maskTensor =
        OrtValueTensor.createTensorWithDataList(attMask, [1, _maxLen]);
    final runOpts = OrtRunOptions();

    try {
      final outputs = await _session!.runAsync(
        runOpts,
        {'input_ids': inTensor, 'attention_mask': maskTensor},
      );

      if (outputs == null || outputs.isEmpty) {
        return const OnnxInferenceResult(label: 'not_financial');
      }

      // cls_logits [1, 7]
      final clsList = outputs[0]?.value as List?;
      final clsLogits = (clsList?[0] as List? ?? [])
          .map((e) => (e as num).toDouble())
          .toList();

      var clsArgmax = 0;
      var clsMax = double.negativeInfinity;
      for (var i = 0; i < clsLogits.length; i++) {
        if (clsLogits[i] > clsMax) {
          clsMax = clsLogits[i];
          clsArgmax = i;
        }
      }
      final label = _id2label[clsArgmax] ?? 'not_financial';

      // Extract merchant from NER for financial messages
      String? merchant;
      if (label == 'expense' || label == 'income' || label == 'transfer') {
        final nerList = outputs[1]?.value as List?;
        final nerSeq = nerList?[0] as List? ?? [];

        final merchantTokens = <String>[];
        // Skip [CLS] at pos 0 and [SEP] at last pos
        for (var pos = 1; pos < tokenIds.length - 1; pos++) {
          if (pos >= nerSeq.length) break;
          final tl = (nerSeq[pos] as List)
              .map((e) => (e as num).toDouble())
              .toList();
          var tagMax = double.negativeInfinity;
          var tagIdx = 0;
          for (var j = 0; j < tl.length; j++) {
            if (tl[j] > tagMax) {
              tagMax = tl[j];
              tagIdx = j;
            }
          }
          final tag = _id2tag[tagIdx] ?? 'O';
          if (tag == 'B-MERCHANT' || tag == 'I-MERCHANT') {
            merchantTokens.add(tokenStrs[pos]);
          }
        }

        if (merchantTokens.isNotEmpty) {
          merchant = _detokenize(merchantTokens);
        }
      }

      for (final o in outputs) {
        o?.release();
      }
      return OnnxInferenceResult(label: label, merchant: merchant);
    } finally {
      inTensor.release();
      maskTensor.release();
      runOpts.release();
    }
  }

  String _detokenize(List<String> tokens) {
    final buf = StringBuffer();
    for (final t in tokens) {
      if (t.startsWith('##')) {
        buf.write(t.substring(2));
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
    }
    return buf.toString().trim();
  }

  static final _amountPatterns = [
    RegExp(r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr)', caseSensitive: false),
    RegExp(r'(?:amount|amt)\D{0,10}([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'(?:debited|credited|paid|charged|spent)\D{0,15}([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
  ];

  static double? extractAmount(String sms) {
    for (final pattern in _amountPatterns) {
      final m = pattern.firstMatch(sms);
      if (m != null) {
        final str = m.group(1)!.replaceAll(',', '');
        final val = double.tryParse(str);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  static String inferCategory(String merchant) {
    final m = merchant.toLowerCase();
    if (['swiggy', 'zomato', 'food', 'restaurant', 'cafe', 'hotel', 'biryani', 'pizza'].any(m.contains)) return 'Food';
    if (['uber', 'ola', 'rapido', 'railway', 'irctc', 'metro', 'flight', 'indigo', 'spicejet'].any(m.contains)) return 'Transport';
    if (['electricity', 'water', 'jio', 'airtel', 'bsnl', 'internet', 'broadband', 'recharge'].any(m.contains)) return 'Utilities';
    if (['netflix', 'hotstar', 'spotify', 'prime', 'zee5', 'cinema', 'pvr', 'inox', 'bookmyshow'].any(m.contains)) return 'Entertainment';
    if (['amazon', 'flipkart', 'myntra', 'meesho', 'nykaa', 'shop', 'mart', 'store', 'ajio'].any(m.contains)) return 'Shopping';
    if (['hospital', 'clinic', 'pharmacy', 'medical', 'doctor', 'apollo', 'medplus', '1mg', 'netmeds'].any(m.contains)) return 'Health';
    return 'Others';
  }
}
