// lib/pan_tompkins_alg.dart
import 'dart:math';
class PanTompkinsQRS {

  static List<double> solve(List<double> signal, double sampleRate) {
    List<double> result = bandPassFilter(signal);


    return result;
  }

  

  static List<double> bandPassFilter(List<double> signal) {
    List<double> sig = List.from(signal);
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];

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

    double maxVal = max(result.reduce(max), -result.reduce(min));
    result = result.map((val) => val / maxVal).toList();

    return result;
  }
}