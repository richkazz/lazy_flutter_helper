import 'package:flutter/material.dart';
import 'package:lazy_flutter_helper/src/spacing/app_spacing.dart';
import 'package:lazy_flutter_helper/src/src.dart';

class ButtonStyles {
  static const EdgeInsets padding = EdgeInsets.only(
    left: AppSpacing.xlg,
    right: AppSpacing.xlg,
  );
}

class ButtonFilled extends StatelessWidget {
  const ButtonFilled({
    required this.buttonText,
    required this.onPressed,
    this.borderRadius = 10,
    this.disabled = false,
    super.key,
  });
  final String buttonText;
  final VoidCallback onPressed;
  final double borderRadius;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ButtonStyles.padding,
      child: FilledButton(
        style: FilledButton.styleFrom(
          maximumSize: const Size(double.infinity, 50),
          minimumSize: const Size(100, 30),
          backgroundColor: AppColors.filledButtonBackgroundColor,
          disabledBackgroundColor: AppColors.disabledButtonBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        onPressed: disabled ? null : onPressed,
        child: ButtonText(
          buttonText: buttonText,
          color: AppColors.filledButtonTextColor,
        ),
      ),
    );
  }
}

class ButtonOutlined extends StatelessWidget {
  const ButtonOutlined({
    required this.buttonText,
    required this.onPressed,
    this.borderRadius = 10,
    super.key,
  });
  final String buttonText;
  final VoidCallback onPressed;
  final double borderRadius;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ButtonStyles.padding,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          maximumSize: const Size(double.infinity, 50),
          minimumSize: const Size(200, 30),
          disabledBackgroundColor: AppColors.disabledButtonBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          buttonText,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w300),
        ),
      ),
    );
  }
}

class ButtonText extends StatelessWidget {
  const ButtonText({
    required this.buttonText,
    super.key,
    this.color,
  });

  final String buttonText;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Text(
      buttonText,
      style: TextStyle(color: color, fontWeight: FontWeight.w300),
    );
  }
}

enum ButtonGradientStyle {
  pts,
  stp;

  LinearGradient gradient(BuildContext context) {
    switch (this) {
      case ButtonGradientStyle.pts:
        return LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        );
      case ButtonGradientStyle.stp:
        return LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.primary,
          ],
        );
    }
  }
}

class ButtonFilledWithSuffixIconAndGradientBackground extends StatelessWidget {
  const ButtonFilledWithSuffixIconAndGradientBackground({
    required this.buttonText,
    this.onPressed,
    super.key,
    this.prefixIcon,
    this.buttonGradientStyle = ButtonGradientStyle.pts,
  });
  final ButtonGradientStyle buttonGradientStyle;
  final String buttonText;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ButtonStyles.padding,
      child: Container(
        decoration: BoxDecoration(
          color: onPressed == null
              ? AppColors.disabledButtonBackgroundColor
              : null,
          gradient:
              onPressed == null ? null : buttonGradientStyle.gradient(context),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            maximumSize: const Size(200, 50),
            minimumSize: const Size(50, 30),
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: prefixIcon == null
              ? Center(
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        prefixIcon,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      buttonText,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(
                      width: 30,
                      height: 30,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
