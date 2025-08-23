// widgets/password_strength_widget.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/password_validator.dart';

class PasswordStrengthWidget extends StatelessWidget {
  final String password;
  final bool showRequirements;
  final VoidCallback? onGeneratePassword;

  const PasswordStrengthWidget({
    Key? key,
    required this.password,
    this.showRequirements = true,
    this.onGeneratePassword,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final validation = PasswordValidator.validatePassword(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength indicator
        if (password.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildStrengthIndicator(context, validation),
        ],

        // Requirements checklist
        if (showRequirements && password.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRequirementsCard(context, validation),
        ],

        // Suggestions
        if (validation.suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSuggestionsCard(context, validation),
        ],

        // Generate password button
        if (onGeneratePassword != null) ...[
          const SizedBox(height: 12),
          _buildGeneratePasswordCard(context),
        ],
      ],
    );
  }

  Widget _buildStrengthIndicator(BuildContext context, PasswordValidationResult validation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PasswordValidator.getStrengthColor(validation.strength).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                size: 16,
                color: PasswordValidator.getStrengthColor(validation.strength),
              ),
              const SizedBox(width: 8),
              Text(
                'Password Strength: ${PasswordValidator.getStrengthText(validation.strength)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: PasswordValidator.getStrengthColor(validation.strength),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: validation.strengthScore,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              PasswordValidator.getStrengthColor(validation.strength),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(validation.strengthScore * 100).toInt()}% strength',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard(BuildContext context, PasswordValidationResult validation) {
    final requirements = [
      _RequirementItem(
        'At least 8 characters',
        password.length >= 8,
        Icons.straighten,
      ),
      _RequirementItem(
        'Uppercase letter (A-Z)',
        password.contains(RegExp(r'[A-Z]')),
        Icons.keyboard_arrow_up,
      ),
      _RequirementItem(
        'Lowercase letter (a-z)',
        password.contains(RegExp(r'[a-z]')),
        Icons.keyboard_arrow_down,
      ),
      _RequirementItem(
        'Number (0-9)',
        password.contains(RegExp(r'[0-9]')),
        Icons.numbers,
      ),
      _RequirementItem(
        'Special character (!@#\$%^&*)',
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
        Icons.star,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...requirements.map((req) => _buildRequirementRow(req)).toList(),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(_RequirementItem requirement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            requirement.isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: requirement.isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Icon(
            requirement.icon,
            size: 14,
            color: requirement.isMet ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement.text,
              style: TextStyle(
                fontSize: 12,
                color: requirement.isMet ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: requirement.isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(BuildContext context, PasswordValidationResult validation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validation.isValid 
            ? Colors.green.shade50 
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: validation.isValid 
              ? Colors.green.shade200 
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                validation.isValid ? Icons.check_circle : Icons.lightbulb_outline,
                size: 16,
                color: validation.isValid 
                    ? Colors.green.shade700 
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                validation.isValid ? 'Great Password!' : 'Suggestions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: validation.isValid 
                      ? Colors.green.shade700 
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...validation.suggestions.take(3).map((suggestion) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  validation.isValid ? '✅ ' : '💡 ',
                  style: const TextStyle(fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      color: validation.isValid 
                          ? Colors.green.shade600 
                          : Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildGeneratePasswordCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a strong password?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'We can generate a secure password for you',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onGeneratePassword,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Generate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementItem {
  final String text;
  final bool isMet;
  final IconData icon;

  _RequirementItem(this.text, this.isMet, this.icon);
}

// Alternative compact version for smaller spaces
class CompactPasswordStrengthWidget extends StatelessWidget {
  final String password;
  final bool showText;

  const CompactPasswordStrengthWidget({
    Key? key,
    required this.password,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final validation = PasswordValidator.validatePassword(password);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PasswordValidator.getStrengthColor(validation.strength).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: PasswordValidator.getStrengthColor(validation.strength).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStrengthIcon(validation.strength),
            size: 16,
            color: PasswordValidator.getStrengthColor(validation.strength),
          ),
          if (showText) ...[
            const SizedBox(width: 6),
            Text(
              PasswordValidator.getStrengthText(validation.strength),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: PasswordValidator.getStrengthColor(validation.strength),
              ),
            ),
          ],
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            height: 4,
            child: LinearProgressIndicator(
              value: validation.strengthScore,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                PasswordValidator.getStrengthColor(validation.strength),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStrengthIcon(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Icons.warning;
      case PasswordStrength.fair:
        return Icons.error;
      case PasswordStrength.good:
        return Icons.check_circle_outline;
      case PasswordStrength.strong:
        return Icons.check_circle;
      case PasswordStrength.veryStrong:
        return Icons.verified;
    }
  }
}