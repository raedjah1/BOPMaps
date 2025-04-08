import 'package:flutter/material.dart';
import '../../config/themes.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  
  const SecondaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonWidget = icon != null
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : Icon(icon),
            label: Text(text),
            style: OutlinedButton.styleFrom(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : Text(text),
          );

    return fullWidth
        ? SizedBox(
            width: double.infinity,
            child: buttonWidget,
          )
        : buttonWidget;
  }
} 