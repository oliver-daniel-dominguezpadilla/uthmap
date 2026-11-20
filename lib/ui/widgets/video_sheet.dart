import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models.dart';
import '../theme.dart';

bool get _videoPlatformSupported {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

Future<void> showVideoSheet(BuildContext context, Building building) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (_) => VideoSheet(building: building),
  );
}

class VideoSheet extends StatefulWidget {
  const VideoSheet({super.key, required this.building});

  final Building building;

  @override
  State<VideoSheet> createState() => _VideoSheetState();
}

class _VideoSheetState extends State<VideoSheet> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loading = false;
  String? _error;

  bool get _supported => _videoPlatformSupported;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final asset = widget.building.videoAsset;
    if (asset == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final video = VideoPlayerController.asset(asset);
      await video.initialize();
      if (!mounted) {
        await video.dispose();
        return;
      }
      _video = video;
      _chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        aspectRatio: video.value.aspectRatio == 0
            ? 16 / 9
            : video.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: AppColors.line,
          backgroundColor: AppColors.lineSoft,
        ),
        errorBuilder: (context, message) => _ErrorView(
          message: 'No se pudo reproducir el video.',
          onRetry: _retry,
          onClose: _close,
        ),
      );
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el recorrido en video.';
      });
    }
  }

  void _retry() {
    _chewie?.dispose();
    _video?.dispose();
    _chewie = null;
    _video = null;
    _initialize();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final building = widget.building;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0C0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECORRIDO EN VIDEO',
                          style: AppTheme.mono(
                            size: 10,
                            weight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          building.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _content(building),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Text(
                _supported
                    ? 'Video demostrativo del inmueble. Requiere conexión solo la primera vez si el archivo se sirve en remoto.'
                    : 'La reproducción integrada está disponible en Android, iOS, macOS y Web. En esta plataforma se muestra la portada del inmueble.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Building building) {
    if (!_supported) {
      return _Poster(building: building, message: null);
    }
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    final chewie = _chewie;
    if (chewie != null) {
      return Chewie(controller: chewie);
    }
    return _ErrorView(
      message: _error ?? 'No se pudo cargar el recorrido.',
      onRetry: _initialize,
      onClose: _close,
      building: building,
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.building, required this.message});

  final Building building;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (building.photoAsset != null)
          Image.asset(building.photoAsset!, fit: BoxFit.cover)
        else
          const ColoredBox(color: AppColors.ink),
        ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 42,
                  color: Colors.white,
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onClose,
    this.building,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final Building? building;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 32,
                color: Colors.white70,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onClose,
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
