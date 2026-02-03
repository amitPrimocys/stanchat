import 'dart:developer';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stanchat/main.dart';
import 'package:stanchat/utils/app_size_config.dart';

class CachedVoicePlayer extends StatelessWidget {
  final String voiceUrl;
  final Color playedColor;
  final Color unplayedColor;
  final Color iconColor;
  final Color iconBackgroundColor;
  final double buttonSize;
  final bool showTiming;
  final TextStyle? timingStyle;
  final bool isSender;

  const CachedVoicePlayer({
    super.key,
    required this.voiceUrl,
    this.playedColor = Colors.blue,
    this.unplayedColor = Colors.grey,
    this.iconColor = Colors.blue,
    this.iconBackgroundColor = Colors.white,
    this.buttonSize = 40,
    this.showTiming = true,
    this.timingStyle,
    required this.isSender,
  });

  // Static cache: URL → waveform data
  static final Map<String, List<double>> _waveformCache = {};
  static final Map<String, bool> _loading = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: _getCachedWaveform(voiceUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Fully loaded → show real player with real waveform
          return WavedAudioPlayer(
            source: UrlSource(voiceUrl),
            playedColor: playedColor,
            unplayedColor: unplayedColor,
            iconColor: iconColor,
            iconBackgoundColor: iconBackgroundColor,
            buttonSize: buttonSize,
            showTiming: showTiming,
            timingStyle: timingStyle,
            waveWidth: SizeConfig.screenWidth / 2.3,
            waveHeight: 20,
            barWidth: 2,
            spacing: 1,
            // Pass cached waveform via a dummy source or modify WavedAudioPlayer to accept waveform
          );
        } else if (snapshot.hasError) {
          return _placeholderPlayer();
        } else {
          // Loading → show placeholder with fake waveform
          return _placeholderPlayer();
        }
      },
    );
  }

  Widget _placeholderPlayer() {
    return WavedAudioPlayer(
      source: UrlSource(voiceUrl), // Still loads audio, but no waveform yet
      playedColor: unplayedColor.withOpacity(0.5),
      unplayedColor: unplayedColor.withOpacity(0.3),
      iconColor: iconColor.withOpacity(0.6),
      iconBackgoundColor: iconBackgroundColor,
      buttonSize: buttonSize,
      showTiming: showTiming,
      timingStyle: timingStyle?.copyWith(color: Colors.grey),
      waveWidth: SizeConfig.screenWidth / 2.3,
      waveHeight: 20,
      barWidth: 2,
      spacing: 1,
    );
  }

  Future<List<double>> _getCachedWaveform(String url) async {
    // Already cached?
    if (_waveformCache.containsKey(url)) {
      return _waveformCache[url]!;
    }

    // Already loading? Wait for it
    if (_loading.containsKey(url) && _loading[url] == true) {
      // Wait a bit and retry (simple polling)
      await Future.delayed(const Duration(milliseconds: 100));
      return _getCachedWaveform(url);
    }

    // Start loading
    _loading[url] = true;

    try {
      final bytes = await _downloadAudioBytes(url);
      final waveform = _extractWaveform(bytes);
      _waveformCache[url] = waveform;
      return waveform;
    } finally {
      _loading[url] = false;
    }
  }

  Future<Uint8List> _downloadAudioBytes(String url) async {
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) throw Exception("Failed to load audio");
    return await consolidateHttpClientResponseBytes(response);
  }

  List<double> _extractWaveform(Uint8List bytes) {
    const int targetBars = 80; // Adjust for your waveWidth
    final step = (bytes.length / targetBars).floor().clamp(1, bytes.length);
    return List.generate(
      targetBars,
      (i) => bytes[(i * step).clamp(0, bytes.length - 1)] / 255.0,
    );
  }
}

// ignore: must_be_immutable
class WavedAudioPlayer extends StatefulWidget {
  Source source;
  Color playedColor;
  Color unplayedColor;
  Color iconColor;
  Color iconBackgoundColor;
  double barWidth;
  double spacing;
  double waveHeight;
  double buttonSize;
  double waveWidth;
  bool showTiming;
  TextStyle? timingStyle;
  void Function(WavedAudioPlayerError)? onError;
  WavedAudioPlayer({
    super.key,
    required this.source,
    this.playedColor = Colors.blue,
    this.unplayedColor = Colors.grey,
    this.iconColor = Colors.blue,
    this.iconBackgoundColor = Colors.white,
    this.barWidth = 2,
    this.spacing = 4,
    this.waveWidth = 200,
    this.buttonSize = 40,
    this.showTiming = true,
    this.timingStyle,
    this.onError,
    this.waveHeight = 35,
  });

  @override
  _WavedAudioPlayerState createState() => _WavedAudioPlayerState();
}

class _WavedAudioPlayerState extends State<WavedAudioPlayer>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final AudioPlayer _audioPlayer;

  Uint8List? _audioBytes;
  List<double> waveformData = [];

  Duration audioDuration = Duration.zero;
  Duration currentPosition = Duration.zero;

  List<double> defaultWaveformData = List.generate(
    50,
    (index) => (index % 5 == 0) ? 0.9 : 0.3,
  );

  bool isPlaying = false;
  bool isPausing = true;

  @override
  void initState() {
    super.initState();
    logger.v("New_Voice:${widget.source}");
    _audioPlayer = AudioPlayer();
    _loadWaveform();
    _setupAudioPlayer();
  }

  @override
  void didUpdateWidget(covariant WavedAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source) {
      _resetPlayer();
      _loadWaveform();
    }
  }

  void _resetPlayer() {
    _audioPlayer.stop();
    _audioPlayer.release();

    _audioBytes = null;
    waveformData.clear();
    audioDuration = Duration.zero;
    currentPosition = Duration.zero;
    isPlaying = false;

    if (mounted) setState(() {});
  }

  // Future<void> _loadWaveform() async {
  //   try {
  //     if (widget.source is UrlSource) {
  //       final url = (widget.source as UrlSource).url;
  //       final request = await HttpClient().getUrl(Uri.parse(url));
  //       final response = await request.close();
  //       _audioBytes = await consolidateHttpClientResponseBytes(response);
  //     }

  //     if (_audioBytes == null) return;

  //     waveformData = _extractWaveformData(_audioBytes!);

  //     await _audioPlayer.setSource(
  //       BytesSource(_audioBytes!, mimeType: widget.source.mimeType),
  //     );

  //     if (mounted) setState(() {});
  //   } catch (e) {
  //     widget.onError?.call(WavedAudioPlayerError("Audio load failed: $e"));
  //   }
  // }

  Future<void> _loadWaveform() async {
    try {
      if (_audioBytes == null) {
        log("🎶 URL BytesSource is null 🎶");
        if (widget.source is AssetSource) {
          log("🎶 URL Assets source 🎶");
          _audioBytes = await _loadAssetAudioWaveform(
            (widget.source as AssetSource).path,
          );
        } else if (widget.source is UrlSource) {
          log("🎶 URL network Url source load 🎶");
          _audioBytes = await _loadRemoteAudioWaveform(
            (widget.source as UrlSource).url,
          );
        } else if (widget.source is DeviceFileSource) {
          log("🎶 URL Device File source load 🎶");
          _audioBytes = await _loadDeviceFileAudioWaveform(
            (widget.source as DeviceFileSource).path,
          );
        } else if (widget.source is BytesSource) {
          log("🎶 URL Bytes souce 🎶");
          _audioBytes = (widget.source as BytesSource).bytes;
        }
        waveformData = _extractWaveformData(_audioBytes!);
        setState(() {});
      }
      log("🎶 URL BytesSource not null 🎶");
      _audioPlayer.setSource(
        BytesSource(_audioBytes!, mimeType: widget.source.mimeType),
      );
    } catch (e) {
      _callOnError(WavedAudioPlayerError("Error loading audio: $e"));
    }
  }

  Future<Uint8List?> _loadDeviceFileAudioWaveform(String filePath) async {
    try {
      final File file = File(filePath);
      final Uint8List audioBytes = await file.readAsBytes();
      return audioBytes;
    } catch (e) {
      _callOnError(WavedAudioPlayerError("Error loading file audio: $e"));
    }
    return null;
  }

  Future<Uint8List?> _loadAssetAudioWaveform(String path) async {
    try {
      final ByteData bytes = await rootBundle.load(path);
      return bytes.buffer.asUint8List();
    } catch (e) {
      _callOnError(WavedAudioPlayerError("Error loading asset audio: $e"));
    }
    return null;
  }

  Future<Uint8List?> _loadRemoteAudioWaveform(String url) async {
    try {
      final HttpClient httpClient = HttpClient();
      final HttpClientRequest request = await httpClient.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        return await consolidateHttpClientResponseBytes(response);
      } else {
        _callOnError(
          WavedAudioPlayerError("Failed to load audio: ${response.statusCode}"),
        );
      }

      httpClient.close();
    } catch (e) {
      _callOnError(WavedAudioPlayerError("Error loading audio: $e"));
    }
    return null;
  }

  void _callOnError(WavedAudioPlayerError error) {
    if (widget.onError == null) return;
    print('\x1B[31m ${error.message}\x1B[0m');
    widget.onError!(error);
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.playing) {
        setState(() {
          isPlaying = true;
        });
      } else {
        setState(() {
          isPlaying = false;
        });
      }
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      isPausing = false;
      _audioPlayer.release();
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        audioDuration = duration;
        isPausing = true;
      });
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        currentPosition = position;
        isPausing = true;
      });
    });
  }

  // void _setupAudioPlayer() {
  //   _audioPlayer.onPlayerStateChanged.listen((state) {
  //     if (!mounted) return;
  //     setState(() => isPlaying = state == PlayerState.playing);
  //   });

  //   _audioPlayer.onDurationChanged.listen((d) {
  //     if (!mounted) return;
  //     setState(() => audioDuration = d);
  //   });

  //   _audioPlayer.onPositionChanged.listen((p) {
  //     if (!mounted) return;
  //     setState(() => currentPosition = p);
  //   });

  //   _audioPlayer.onPlayerComplete.listen((_) {
  //     if (!mounted) return;
  //     setState(() {
  //       isPlaying = false;
  //       currentPosition = Duration.zero;
  //     });
  //   });
  // }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return "${twoDigits(hours)}:$minutes:$seconds"; // Format as HH:MM:SS
    } else {
      return "$minutes:$seconds"; // Format as MM:SS
    }
  }

  List<double> _extractWaveformData(Uint8List audioBytes) {
    List<double> waveData = [];
    int step =
        (audioBytes.length /
                (widget.waveWidth / (widget.barWidth + widget.spacing)))
            .floor();
    for (int i = 0; i < audioBytes.length; i += step) {
      waveData.add(audioBytes[i] / 255);
    }
    waveData.add(audioBytes[audioBytes.length - 1] / 255);
    return waveData;
  }
  // List<double> _extractWaveformData(Uint8List bytes) {
  //   final int bars =
  //       (widget.waveWidth / (widget.barWidth + widget.spacing)).floor();
  //   final int step = (bytes.length / bars).floor().clamp(1, bytes.length);

  //   return List.generate(
  //     bars,
  //     (i) => bytes[(i * step).clamp(0, bytes.length - 1)] / 255,
  //   );
  // }

  void _onWaveformTap(double tapX, double width) {
    double tapPercent = tapX / width;
    Duration newPosition = audioDuration * tapPercent;
    _audioPlayer.seek(newPosition);
  }

  void _playAudio() async {
    if (_audioBytes == null) return;
    isPausing
        ? _audioPlayer.resume()
        : _audioPlayer.play(
          BytesSource(_audioBytes!, mimeType: widget.source.mimeType),
        );
  }

  void _pauseAudio() async {
    _audioPlayer.pause();
    isPausing = true;
  }

  // void _playPause() async {
  //   if (_audioBytes == null) return;

  //   if (isPlaying) {
  //     await _audioPlayer.pause();
  //   } else {
  //     await _audioPlayer.resume();
  //   }
  // }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return (waveformData.isNotEmpty)
        ? Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
            GestureDetector(
              onTap:
              //_playPause,
              () {
                isPlaying ? _pauseAudio() : _playAudio();
                setState(() {
                  isPlaying = !isPlaying;
                });
              },
              child: Container(
                height: widget.buttonSize,
                width: widget.buttonSize,
                decoration: BoxDecoration(
                  color: widget.iconBackgoundColor,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: widget.iconColor,
                  size: 4 * widget.buttonSize / 5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            RepaintBoundary(
              child: GestureDetector(
                onTapDown: (TapDownDetails details) {
                  // Call _onWaveformTap when the user taps on the waveform
                  _onWaveformTap(details.localPosition.dx, widget.waveWidth);
                },
                child: CustomPaint(
                  size: Size(widget.waveWidth, widget.waveHeight),
                  painter: WaveformPainter(
                    waveformData,
                    currentPosition.inMilliseconds /
                        (audioDuration.inMilliseconds == 0
                            ? 1
                            : audioDuration.inMilliseconds),
                    playedColor: widget.playedColor,
                    unplayedColor: widget.unplayedColor,
                    barWidth: widget.barWidth,
                  ), // Use your wave data
                ),
              ),
            ),
            if (widget.showTiming) const SizedBox(width: 7),
            if (widget.showTiming)
              Center(
                child: Text(
                  _formatDuration(currentPosition),
                  style: widget.timingStyle,
                ),
              ),
          ],
        )
        : Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
            Container(
              height: widget.buttonSize,
              width: widget.buttonSize,
              decoration: BoxDecoration(
                color: widget.iconBackgoundColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: widget.iconColor,
                size: 4 * widget.buttonSize / 5,
              ),
            ),
            const SizedBox(width: 10),
            RepaintBoundary(
              child: GestureDetector(
                onTapDown: (TapDownDetails details) {
                  // Call _onWaveformTap when the user taps on the waveform
                  _onWaveformTap(details.localPosition.dx, widget.waveWidth);
                },
                child: CustomPaint(
                  size: Size(SizeConfig.screenWidth / 2.3, widget.waveHeight),
                  painter: WaveformPainter(
                    defaultWaveformData,
                    1,
                    playedColor: widget.unplayedColor,
                    unplayedColor: widget.unplayedColor,
                    barWidth: widget.barWidth,
                  ), // Use your wave data
                ),
              ),
            ),
            SizedBox(width: 7),
            Center(
              child: Text(
                _formatDuration(Duration(milliseconds: 500)),
                style: widget.timingStyle,
              ),
            ),
          ],
        );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;

  WaveformPainter(
    this.waveformData,
    this.progress, {
    required this.playedColor,
    required this.unplayedColor,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round;

    final middleY = size.height / 2;
    final playedLines = (waveformData.length * progress).round();

    for (int i = 0; i < waveformData.length; i++) {
      final x = (size.width / waveformData.length) * i;
      final barHeight = waveformData[i] * middleY;

      paint.color = i <= playedLines ? playedColor : unplayedColor;

      canvas.drawLine(
        Offset(x, middleY - barHeight),
        Offset(x, middleY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) {
    // ✅ repaint ONLY when needed
    return old.progress != progress ||
        old.waveformData != waveformData ||
        old.playedColor != playedColor ||
        old.unplayedColor != unplayedColor ||
        old.barWidth != barWidth;
  }
}

class WavedAudioPlayerError extends Error {
  final String message;

  WavedAudioPlayerError(this.message);

  @override
  String toString() => "WavedAudioPlayerError: $message";
}
