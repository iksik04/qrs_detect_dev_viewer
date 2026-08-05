// lib/pan_tompkins_alg.dart
import 'dart:math';

class PanTompkinsQRS {
  // Коэффициенты фильтров
  List<double> bhp = [];
  List<double> ahp = [];
  List<double> blp = [];
  List<double> alp = [];

  // Состояния фильтров (для последовательной обработки)
  double _lprevFiltered = 0.0;
  double _lprevUnfiltered = 0.0;
  double _lprevprevUnfiltered = 0.0;
  double _lprevprevFiltered = 0.0;

  double _hprevFiltered = 0.0;
  double _hprevUnfiltered = 0.0;
  double _hprevprevUnfiltered = 0.0;
  double _hprevprevFiltered = 0.0;

  /// Инициализация коэффициентов в зависимости от частоты дискретизации
  void calculateFilterCoefficients(double sampleRate) {
    final int rate = sampleRate.round();

    if (rate == 125) {
      // ФНЧ (Low-Pass) для 125 Гц
      blp = [0.35034638, 0.70069276, 0.35034638];
      alp = [-0.22115344, -0.18023207];
      // ФВЧ (High-Pass) для 125 Гц
      bhp = [0.96851735, -1.93703469, 0.96851735];
      ahp = [1.93604329, -0.9380261];
    } else if (rate == 250) {
      blp = [0.11735104, 0.23470207, 0.11735104];
      alp = [0.82523238, -0.29463653];
      bhp = [0.98413284, -1.96826569, 0.98413284];
      ahp = [1.96801391, -0.96851747];
    } else if (rate == 360) {
      blp = [0.06433216, 0.12866431, 0.06433216];
      alp = [1.16557175, -0.42290037];
      bhp = [0.98895425, -1.9779085, 0.98895425];
      ahp = [1.97778648, -0.97803051];
    } else {
      // Если частота не поддерживается, используем коэффициенты для 360 Гц по умолчанию
      blp = [0.06433216, 0.12866431, 0.06433216];
      alp = [1.16557175, -0.42290037];
      bhp = [0.98895425, -1.9779085, 0.98895425];
      ahp = [1.97778648, -0.97803051];
    }
  }

  /// Фильтр низких частот (одна итерация)
  double _applyLowPassFilter(double val) {
    double y = blp[0] * val +
        alp[0] * _lprevFiltered +
        blp[1] * _lprevUnfiltered +
        alp[1] * _lprevprevFiltered +
        blp[2] * _lprevprevUnfiltered;
    _lprevprevFiltered = _lprevFiltered;
    _lprevFiltered = y;
    _lprevprevUnfiltered = _lprevUnfiltered;
    _lprevUnfiltered = val;
    return y;
  }

  /// Фильтр высоких частот (одна итерация)
  double _applyHighPassFilter(double val) {
    double y = bhp[0] * val +
        ahp[0] * _hprevFiltered +
        bhp[1] * _hprevUnfiltered +
        ahp[1] * _hprevprevFiltered +
        bhp[2] * _hprevprevUnfiltered;
    _hprevprevFiltered = _hprevFiltered;
    _hprevFiltered = y;
    _hprevprevUnfiltered = _hprevUnfiltered;
    _hprevUnfiltered = val;
    return y;
  }

  /// Статический метод, обрабатывающий сигнал через каскад ФНЧ+ФВЧ
  static List<double> solve(List<double> signal, double sampleRate) {
    if (signal.isEmpty) return [];

    // Создаём экземпляр фильтра
    final detector = PanTompkinsQRS();
    detector.calculateFilterCoefficients(sampleRate);

    // Применяем фильтры последовательно
    final List<double> filtered = List.filled(signal.length, 0.0);
    for (int i = 0; i < signal.length; i++) {
      double low = detector._applyLowPassFilter(signal[i]);
      filtered[i] = detector._applyHighPassFilter(low);
    }

    // Нормализация (опционально)
    if (filtered.isNotEmpty) {
      double maxAbs = filtered.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());
      if (maxAbs != 0) {
        return filtered.map((v) => v / maxAbs).toList();
      }
    }
    return filtered;
  }
}