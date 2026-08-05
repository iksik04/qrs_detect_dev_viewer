// lib/pan_tompkins_alg.dart
//import 'dart:math';

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
    // пологса пропускания 5-15 Гц
    if (rate == 125) {
      // ФНЧ (Low-Pass) для 125 Гц
      _blp = [0.0913149, 0.1826298, 0.0913149];
      _alp = [0.98240579, -0.34766539];
      // ФВЧ (High-Pass) для 125 Гц
      _bhp = [0.83708919, -1.67417838, 0.83708919];
      _ahp = [1.64745998, -0.70089678];
    } else if (rate == 250) {
      _blp = [0.02785977, 0.05571953, 0.02785977];
      _alp = [1.47548044, -0.58691951];
      _bhp = [0.91496914, -1.82993829, 0.91496914];
      _ahp = [1.82269493, -0.83718165];
    } else if (rate == 360) {
      _blp = [0.01440144, 0.02880288, 0.01440144];
      _alp = [1.63299316, -0.69059892];
      _bhp = [0.94015696, -1.88031393, 0.94015696];
      _ahp = [1.87672953, -0.88389833];
    } else {
      // Если частота не поддерживается, используем коэффициенты для 360 Гц по умолчанию
      _blp = [0.01440144, 0.02880288, 0.01440144];
      _alp = [1.63299316, -0.69059892];
      _bhp = [0.94015696, -1.88031393, 0.94015696];
      _ahp = [1.87672953, -0.88389833];
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
    return filtered;
  }
}