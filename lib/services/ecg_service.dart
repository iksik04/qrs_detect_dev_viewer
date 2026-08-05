import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import '../models/ecg_data.dart';
import '../constants/app_constants.dart';
import '../pan-tompkins-alg.dart'; // новый импорт

class ECGService {
  final String _rdsampPath = AppStrings.rdsampPath;
  final String _rdannPath = AppStrings.rdannPath;
  static const String _basePath = AppStrings.basePath;

  /// Загрузка данных ЭКГ с использованием rdsamp и rdann (только для .atr)
  Future<ECGData> loadECGData(String folder, String number) async {
    try {
      final recordName = '$folder/$number';
      final fullPath = '$_basePath\\$folder\\$number';

      print('Загрузка данных: $recordName');
      print('Полный путь: $fullPath');

      // Проверяем существование файлов
      final heaFile = File(fullPath + '.hea');
      if (!await heaFile.exists()) {
        print('Файл $fullPath.hea не найден');
        return ECGData(spots: [], truePeaks: [], processedSignal: []);
      }

      final datFile = File(fullPath + '.dat');
      if (!await datFile.exists()) {
        print('Файл $fullPath.dat не найден');
        return ECGData(spots: [], truePeaks: [], processedSignal: []);
      }

      // Загружаем данные через rdsamp
      final spots = await _loadSpotsWithRDSamp(recordName, fullPath);

      // Загружаем истинные пики из .atr (только они нужны)
      final truePeaks = await _loadPeaksWithRDAnn(recordName, fullPath, 'atr');

      // Получаем частоту дискретизации
      final sampleRate = await getSampleRate(fullPath);

      // Вычисляем обработанный сигнал с помощью Pan-Tompkins
      final signalValues = spots.map((s) => s.y).toList();
      final processed = PanTompkinsQRS.solve(signalValues, sampleRate);

      return ECGData(
        spots: spots,
        truePeaks: truePeaks,
        processedSignal: processed,
        sampleRate: sampleRate,
      );
    } catch (e) {
      print('Ошибка загрузки данных для папки $folder, записи #$number: $e');
      return ECGData(spots: [], truePeaks: [], processedSignal: []);
    }
  }

  /// Загрузка данных через rdsamp (без изменений)
  Future<List<FlSpot>> _loadSpotsWithRDSamp(String recordName, String fullPath) async {
    try {
      final heaFile = File(fullPath + '.hea');
      if (!await heaFile.exists()) {
        print('Файл $fullPath.hea не найден');
        return [];
      }

      final recordPath = recordName.replaceAll('\\', '/');
      print('Вызов rdsamp: $_rdsampPath -r $recordPath -f 0 -t end -p -v');

      final process = await Process.start(
        _rdsampPath,
        ['-r', recordPath, '-f', '0', '-t', 'end', '-p', '-v'],
        mode: ProcessStartMode.normal,
        environment: {
          'WFDB': _basePath,
        },
      );

      final output = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Ошибка rdsamp (код $exitCode): $stderr');
        return [];
      }

      return _parseRDSampOutput(output);
    } catch (e) {
      print('Ошибка выполнения rdsamp: $e');
      return [];
    }
  }

  /// Загрузка пиков через rdann (только для заданного типа аннотаций)
  Future<List<int>> _loadPeaksWithRDAnn(String recordName, String fullPath, String annotationType) async {
    try {
      final annFile = File('$fullPath.$annotationType');
      if (!await annFile.exists()) {
        print('Файл $fullPath.$annotationType не найден');
        return [];
      }

      final recordPath = recordName.replaceAll('\\', '/');
      print('Вызов rdann: $_rdannPath -r $recordPath -a $annotationType -f 0 -t end');

      final process = await Process.start(
        _rdannPath,
        ['-r', recordPath, '-a', annotationType, '-f', '0', '-t', 'end'],
        mode: ProcessStartMode.normal,
        environment: {
          'WFDB': _basePath,
        },
      );

      final output = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Ошибка rdann для $annotationType (код $exitCode): $stderr');
        return [];
      }

      final peaks = _parseRDAnnOutput(output);
      print('Загружено ${peaks.length} пиков из аннотаций $annotationType');
      return peaks;
    } catch (e) {
      print('Ошибка выполнения rdann для $annotationType: $e');
      return [];
    }
  }

  /// Парсинг вывода rdsamp (без изменений)
  List<FlSpot> _parseRDSampOutput(String output) {
    final lines = output.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      print('Вывод rdsamp пуст');
      return [];
    }

    final spots = <FlSpot>[];

    for (final line in lines) {
      try {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) continue;

        final time = double.parse(parts[0]);
        final value = double.parse(parts[1]);

        if (time.isFinite && value.isFinite) {
          spots.add(FlSpot(time, value));
        }
      } catch (e) {
        continue;
      }
    }

    print('Загружено ${spots.length} точек через rdsamp');
    return spots;
  }

  /// Парсинг вывода rdann (без изменений)
  List<int> _parseRDAnnOutput(String output) {
    final lines = output.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      print('Вывод rdann пуст');
      return [];
    }

    final peakIndices = <int>[];

    for (final line in lines) {
      try {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue;

        final sampleNumber = int.tryParse(parts[1]);
        if (sampleNumber == null) continue;

        final annType = parts[2];

        if (_isQRSAnnotation(annType)) {
          if (sampleNumber >= 0) {
            peakIndices.add(sampleNumber);
          }
        }
      } catch (e) {
        continue;
      }
    }

    print('Загружено ${peakIndices.length} пиков из аннотаций');
    return peakIndices;
  }

  bool _isQRSAnnotation(String annotationType) {
    const qrsTypes = {'N', 'L', 'R', 'B', 'A', 'a', 'J', 'S', 'V', 'r', 'F', 'e', 'j', 'n', 'E', 'f', 'Q', '?'};
    return qrsTypes.contains(annotationType);
  }

  Future<bool> isRDSampAvailable() async {
    try {
      final result = await Process.run(_rdsampPath, ['--help']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isRDAnnAvailable() async {
    try {
      final result = await Process.run(_rdannPath, ['--help']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<double> getSampleRate(String fullPath) async {
    try {
      final heaFile = File(fullPath + '.hea');
      if (!await heaFile.exists()) {
        return 360.0;
      }

      final content = await heaFile.readAsString();
      final lines = content.split('\n');

      for (final line in lines) {
        final match = RegExp(r'(\d+)\s+(\d+)\s+(\d+)\s+(\d+(?:\.\d+)?)').firstMatch(line);
        if (match != null && match.groupCount >= 4) {
          return double.parse(match.group(4)!);
        }
      }

      return 360.0;
    } catch (e) {
      print('Ошибка чтения .hea файла: $e');
      return 360.0;
    }
  }
}