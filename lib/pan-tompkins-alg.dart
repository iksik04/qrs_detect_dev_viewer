// lib/pan_tompkins_alg.dart
//import 'dart:math';

class PanTompkinsQRS {

  /*// Коэффициенты фильтров
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
  }*/

  // Буферы для ФНЧ (нужно 13 отсчётов для x[n-12])
  final List<double> _lBuffer = [];
  double _lPrev1 = 0.0;  // y[n-1]
  double _lPrev2 = 0.0;  // y[n-2]

  // Буферы для ФВЧ (нужно 33 отсчёта для x[n-32])
  final List<double> _hBuffer = [];
  double _hPrev1 = 0.0;  // y[n-1]

  double _sampleRate = 250.0;

  PanTompkinsQRS({double sampleRate = 250.0}) {
    _sampleRate = sampleRate;
  }

  void reset() {
    _lBuffer.clear();
    _lPrev1 = 0.0;
    _lPrev2 = 0.0;
    _hBuffer.clear();
    _hPrev1 = 0.0;
  }

  /// ФНЧ: y[n] = 2*y[n-1] - y[n-2] + x[n] - 2*x[n-6] + x[n-12]
  double _applyLowPassFilter(double val) {
    _lBuffer.add(val);
    if (_lBuffer.length > 13) _lBuffer.removeAt(0);

    double xn = _lBuffer[_lBuffer.length - 1];
    double xn6 = (_lBuffer.length - 7 >= 0) ? _lBuffer[_lBuffer.length - 7] : 0.0;
    double xn12 = (_lBuffer.length - 13 >= 0) ? _lBuffer[_lBuffer.length - 13] : 0.0;

    double y = 2.0 * _lPrev1 - _lPrev2 + xn - 2.0 * xn6 + xn12;

    _lPrev2 = _lPrev1;
    _lPrev1 = y;
    return y;
  }

  /// ФВЧ: y[n] = 32*x[n-16] - y[n-1] - x[n] + x[n-32]
  double _applyHighPassFilter(double val) {
    _hBuffer.add(val);
    if (_hBuffer.length > 33) _hBuffer.removeAt(0);

    double xn = _hBuffer[_hBuffer.length - 1];
    double xn16 = (_hBuffer.length - 17 >= 0) ? _hBuffer[_hBuffer.length - 17] : 0.0;
    double xn32 = (_hBuffer.length - 33 >= 0) ? _hBuffer[_hBuffer.length - 33] : 0.0;

    double y = 32.0 * xn16 - _hPrev1 - xn + xn32;

    _hPrev1 = y;
    return y;
  }

  // Дифференцирование
  List<double> derivative(List<double> signal, double fs) {
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];

    for (int index = 0; index < signal.length; index++) {
      result[index] = 0;

      if (index >= 1) {
        result[index] -= 2 * signal[index - 1];
      }

      if (index >= 2) {
        result[index] -= signal[index - 2];
      }

      if (index >= 2 && index <= signal.length - 2) {
        result[index] += 2 * signal[index + 1];
      }

      if (index >= 2 && index <= signal.length - 3) {
        result[index] += signal[index + 2];
      }

      result[index] = (result[index] * fs) / 8;
    }
    return result;
  }

  /// Основной метод обработки сигнала (экземплярный)
  List<double> process(List<double> signal) {
    if (signal.isEmpty) return [];

    // Пересчитываем коэффициенты (на случай, если частота изменилась)
    //_calculateFilterCoefficients();
    
    // Сбрасываем состояние перед обработкой нового сигнала
    reset();

    // Применяем фильтры последовательно
    final List<double> filtered = List.filled(signal.length, 0.0);
    for (int i = 0; i < signal.length; i++) {
      double low = _applyLowPassFilter(signal[i]);
      filtered[i] = _applyHighPassFilter(low);
    }
    print("Сигнал отфильтрован");
    //return filtered;
    // Дифференцируем
    final List<double> derivated = derivative(filtered, _sampleRate);
    print("Сигнал продиффенренцирован");
    return derivated;
  }
}