// lib/pan_tompkins_alg.dart
import 'dart:math';

class PanTompkinsQRS {
  // Коэффициенты фильтров
  late List<double> _bhp;
  late List<double> _ahp;
  late List<double> _blp;
  late List<double> _alp;

  // Состояния фильтров (для последовательной обработки)
  double _lprevFiltered = 0.0;
  double _lprevUnfiltered = 0.0;
  double _lprevprevUnfiltered = 0.0;
  double _lprevprevFiltered = 0.0;

  double _hprevFiltered = 0.0;
  double _hprevUnfiltered = 0.0;
  double _hprevprevUnfiltered = 0.0;
  double _hprevprevFiltered = 0.0;

  // Частота дискретизации
  double _sampleRate = 250.0;

  /// Конструктор с указанием частоты дискретизации
  PanTompkinsQRS({double sampleRate = 250.0}) {
    _sampleRate = sampleRate;
    _calculateFilterCoefficients();
  }

  /// Инициализация коэффициентов в зависимости от частоты дискретизации
  void _calculateFilterCoefficients() {
    final int rate = _sampleRate.round();

    if (rate == 125) {
      // ФНЧ (Low-Pass) для 125 Гц
      _blp = [0.35034638, 0.70069276, 0.35034638];
      _alp = [-0.22115344, -0.18023207];
      // ФВЧ (High-Pass) для 125 Гц
      _bhp = [0.96851735, -1.93703469, 0.96851735];
      _ahp = [1.93604329, -0.9380261];
    } else if (rate == 250) {
      _blp = [0.11735104, 0.23470207, 0.11735104];
      _alp = [0.82523238, -0.29463653];
      _bhp = [0.98413284, -1.96826569, 0.98413284];
      _ahp = [1.96801391, -0.96851747];
    } else if (rate == 360) {
      _blp = [0.06433216, 0.12866431, 0.06433216];
      _alp = [1.16557175, -0.42290037];
      _bhp = [0.98895425, -1.9779085, 0.98895425];
      _ahp = [1.97778648, -0.97803051];
    } else {
      // Если частота не поддерживается, используем коэффициенты для 360 Гц по умолчанию
      _blp = [0.06433216, 0.12866431, 0.06433216];
      _alp = [1.16557175, -0.42290037];
      _bhp = [0.98895425, -1.9779085, 0.98895425];
      _ahp = [1.97778648, -0.97803051];
    }
  }

  /// Сброс состояния фильтров
  void reset() {
    _lprevFiltered = 0.0;
    _lprevUnfiltered = 0.0;
    _lprevprevUnfiltered = 0.0;
    _lprevprevFiltered = 0.0;
    _hprevFiltered = 0.0;
    _hprevUnfiltered = 0.0;
    _hprevprevUnfiltered = 0.0;
    _hprevprevFiltered = 0.0;
  }

  /// Фильтр низких частот (одна итерация)
  double _applyLowPassFilter(double val) {
    double y = _blp[0] * val +
        _alp[0] * _lprevFiltered +
        _blp[1] * _lprevUnfiltered +
        _alp[1] * _lprevprevFiltered +
        _blp[2] * _lprevprevUnfiltered;
    
    // Обновляем состояния
    _lprevprevFiltered = _lprevFiltered;
    _lprevFiltered = y;
    _lprevprevUnfiltered = _lprevUnfiltered;
    _lprevUnfiltered = val;
    
    return y;
  }

  /// Фильтр высоких частот (одна итерация)
  double _applyHighPassFilter(double val) {
    double y = _bhp[0] * val +
        _ahp[0] * _hprevFiltered +
        _bhp[1] * _hprevUnfiltered +
        _ahp[1] * _hprevprevFiltered +
        _bhp[2] * _hprevprevUnfiltered;
    
    // Обновляем состояния
    _hprevprevFiltered = _hprevFiltered;
    _hprevFiltered = y;
    _hprevprevUnfiltered = _hprevUnfiltered;
    _hprevUnfiltered = val;
    
    return y;
  }

  /// Полосовой фильтр (альтернативная реализация)
  List<double> bandPassFilter(List<double> signal) {
    if (signal.isEmpty) return [];
    
    List<double> sig = List.from(signal);
    List<double> result = List.filled(signal.length, 0.0);

    // Первый проход
    for (int index = 0; index < signal.length; index++) {
      sig[index] = signal[index];

      if (index >= 1) {
        sig[index] += 2 * sig[index - 1];
      }

      if (index >= 2) {
        sig[index] -= sig[index - 2];
      }

      if (index >= 6) {
        sig[index] -= 2 * signal[index - 6];
      }

      if (index >= 12) {
        sig[index] += signal[index - 12];
      }
    }

    result = List.from(sig);

    // Второй проход
    for (int index = 0; index < signal.length; index++) {
      result[index] = -1 * sig[index];

      if (index >= 1) {
        result[index] -= result[index - 1];
      }

      if (index >= 16) {
        result[index] += 32 * sig[index - 16];
      }

      if (index >= 32) {
        result[index] += sig[index - 32];
      }
    }
    return result;
  }

  /// Основной метод обработки сигнала (экземплярный)
  List<double> process(List<double> signal, {bool normalize = true}) {
    if (signal.isEmpty) return [];
    
    // Пересчитываем коэффициенты (на случай, если частота изменилась)
    _calculateFilterCoefficients();
    
    // Сбрасываем состояние перед обработкой нового сигнала
    reset();

    // Применяем фильтры последовательно
    final List<double> filtered = List.filled(signal.length, 0.0);
    for (int i = 0; i < signal.length; i++) {
      double low = _applyLowPassFilter(signal[i]);
      filtered[i] = _applyHighPassFilter(low);
    }

    // Нормализация (опционально)
    if (normalize && filtered.isNotEmpty) {
      double maxAbs = filtered.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());
      if (maxAbs != 0) {
        return filtered.map((v) => v / maxAbs).toList();
      }
    }

    return filtered;
  }

  /// Альтернативный метод с использованием bandPassFilter
  List<double> processWithBandPass(List<double> signal) {
    return bandPassFilter(signal);
  }
}