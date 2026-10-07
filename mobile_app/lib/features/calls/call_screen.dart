import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/calls/call_manager.dart';
import '../../core/theme/app_colors.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _m = CallManager.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onChange);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _m.phase == CallPhase.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _m.removeListener(_onChange);
    _m.screenClosed();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (_m.phase == CallPhase.idle) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  String get _status {
    switch (_m.phase) {
      case CallPhase.outgoing:
        return 'Inaita…';
      case CallPhase.incoming:
        return 'Simu ya sauti inaingia…';
      case CallPhase.connecting:
        return 'Inaunganisha…';
      case CallPhase.active:
        final d = DateTime.now().difference(_m.connectedAt ?? DateTime.now());
        final m = d.inMinutes.toString().padLeft(2, '0');
        final s = (d.inSeconds % 60).toString().padLeft(2, '0');
        return '$m:$s';
      case CallPhase.ended:
        return _m.endMessage ?? 'Simu imeisha';
      case CallPhase.idle:
        return '';
    }
  }

  String get _initials {
    final parts = _m.otherName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final ringing =
        _m.phase == CallPhase.outgoing || _m.phase == CallPhase.incoming;

    return PopScope(
      canPop: false, // simu inakatwa kwa kitufe cha Kata tu
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: 13, color: Colors.white54),
                    SizedBox(width: 6),
                    Text(
                      'Simu ya DesignBora • Haionyeshi namba yako',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                _Avatar(initials: _initials, pulsing: ringing),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _m.otherName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _m.phase == CallPhase.ended
                          ? Colors.orangeAccent
                          : Colors.white70,
                      fontSize: _m.phase == CallPhase.active ? 20 : 15,
                      fontWeight: _m.phase == CallPhase.active
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (_m.orderId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Oda #${_m.orderId}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
                const Spacer(flex: 3),
                _buildControls(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    switch (_m.phase) {
      case CallPhase.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.call_end_rounded,
              label: 'Kataa',
              color: Colors.redAccent,
              onTap: _m.reject,
            ),
            _RoundButton(
              icon: Icons.call_rounded,
              label: 'Pokea',
              color: Colors.green,
              onTap: _m.accept,
            ),
          ],
        );
      case CallPhase.ended:
        return const SizedBox(height: 96);
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: _m.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _m.muted ? 'Washa sauti' : 'Zima sauti',
              color: _m.muted ? Colors.white : Colors.white12,
              iconColor: _m.muted ? AppColors.primary : Colors.white,
              onTap: _m.toggleMute,
            ),
            _RoundButton(
              icon: Icons.call_end_rounded,
              label: 'Kata',
              color: Colors.redAccent,
              size: 72,
              onTap: () => _m.hangUp(),
            ),
            _RoundButton(
              icon: Icons.volume_up_rounded,
              label: 'Spika',
              color: _m.speaker ? Colors.white : Colors.white12,
              iconColor: _m.speaker ? AppColors.primary : Colors.white,
              onTap: _m.toggleSpeaker,
            ),
          ],
        );
    }
  }
}

class _Avatar extends StatefulWidget {
  final String initials;
  final bool pulsing;
  const _Avatar({required this.initials, required this.pulsing});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: 120 + 60 * _c.value,
                height: 120 + 60 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(
                    alpha: 0.35 * (1 - _c.value),
                  ),
                ),
              ),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.accent,
              child: Text(
                widget.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: iconColor, size: size * 0.42),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
      ],
    );
  }
}
