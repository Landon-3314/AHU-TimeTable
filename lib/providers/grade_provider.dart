import 'package:flutter/foundation.dart';

import '../models/grade.dart';
import '../services/storage_service.dart';

class GradeProvider extends ChangeNotifier {
  GradeProvider({required StorageService storageService})
    : _storageService = storageService;

  final StorageService _storageService;

  GradeBook? _gradeBook;
  bool _isRefreshing = false;
  String? _lastError;

  GradeBook? get gradeBook => _gradeBook;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;

  Future<void> loadCached() async {
    _gradeBook = _storageService.loadGradeBook();
    _lastError = null;
    notifyListeners();
  }

  Future<void> replaceWithFetched(GradeBook book) async {
    _gradeBook = book;
    _lastError = null;
    await _storageService.saveGradeBook(book);
    notifyListeners();
  }

  Future<bool> refreshViaWebView(Future<GradeBook> Function() fetchBook) async {
    if (_isRefreshing) {
      return false;
    }
    _isRefreshing = true;
    _lastError = null;
    notifyListeners();
    try {
      final book = await fetchBook();
      await _storageService.saveGradeBook(book);
      _gradeBook = book;
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> clearCache() async {
    await _storageService.clearGradeBook();
    _gradeBook = null;
    _lastError = null;
    notifyListeners();
  }
}
