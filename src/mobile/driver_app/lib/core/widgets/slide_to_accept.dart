import 'package:flutter/material.dart';

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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              "Slide to Accept Job",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
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
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: const [
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
