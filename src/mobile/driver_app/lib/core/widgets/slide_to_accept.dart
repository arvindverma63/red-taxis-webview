import 'package:flutter/material.dart';
import 'package:driver_app/core/theme/theme.dart';

class SlideToAccept extends StatefulWidget {
  final VoidCallback onAccept;
  const SlideToAccept({super.key, required this.onAccept});

  @override
  State<SlideToAccept> createState() => _SlideToAcceptState();
}

class _SlideToAcceptState extends State<SlideToAccept> {
  double _dragPosition = 0.0;
  final double _sliderWidth = 300.0;
  final double _thumbSize = 54.0;

  @override
  Widget build(BuildContext context) {
    final maxDrag = _sliderWidth - _thumbSize - 4.0;

    return Container(
      width: _sliderWidth,
      height: 60,
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              "Slide to Accept Job",
              style: TextStyle(
                color: AppTheme.primaryRed,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Positioned(
            left: _dragPosition,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPosition += details.delta.dx;
                  if (_dragPosition < 0) _dragPosition = 0;
                  if (_dragPosition > maxDrag) {
                    _dragPosition = maxDrag;
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragPosition >= maxDrag - 10) {
                  widget.onAccept();
                } else {
                  setState(() {
                    _dragPosition = 0.0;
                  });
                }
              },
              child: Container(
                width: _thumbSize,
                height: 54,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
