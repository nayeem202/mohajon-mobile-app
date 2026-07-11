import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.onPressed,
    this.isBusy = false,
  });

  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onPressed,
            icon: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              isBusy ? 'Saving...' : 'Save Changes',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
