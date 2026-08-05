import 'package:fl_chart/fl_chart.dart';

/// Модель данных ЭКГ, содержащая точки сигнала,
/// индексы истинных R-пиков и обработанный сигнал.
class ECGData {
  final List<FlSpot> spots;
  final List<int> truePeaks;          // индексы R-пиков из .atr
  final List<double> processedSignal; // результат работы Pan-Tompkins (длина равна spots.length)
  final double sampleRate;            // частота дискретизации

  ECGData({
    required this.spots,
    required this.truePeaks,
    required this.processedSignal,
    this.sampleRate = 360.0,
  });

  bool get isEmpty => spots.isEmpty;
}