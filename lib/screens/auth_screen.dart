// Replace your existing auth_screen.dart with this enhanced version
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/providers/user_profile_provider.dart';
import 'package:myapp/services/email_service.dart';
import 'package:myapp/services/password_validator.dart';
import 'package:myapp/widgets/password_strength_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _hasCheckedAuth = false;
  bool _acceptTerms = false;
  
  // Password validation
  bool _showPasswordRequirements = false;

  @override
  void initState() {
    super.initState();
    // Check auth state after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedAuth) {
        _checkExistingAuth();
      }
    });
  }

  Future<void> _checkExistingAuth() async {
    setState(() {
      _hasCheckedAuth = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      print('User already logged in: ${user.email}');
      await _handleAuthenticatedUser(user, isExistingSession: true);
    }
  }

  Future<void> _handleAuthenticatedUser(User user, {bool isExistingSession = false}) async {
    try {
      print('Checking profile for user: ${user.uid}');
      
      final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
      final hasProfile = await userProfileProvider.hasCompletedProfile(user.uid);
      
      print('User has profile: $hasProfile');
      
      if (mounted) {
        if (hasProfile) {
          // Always load the user profile first to get the name
          await userProfileProvider.fetchUserProfile(user.uid);
          print('User profile loaded: ${userProfileProvider.displayName}');
          
          // Check if this is a new login session and if welcome hasn't been seen
          if (!isExistingSession) {
            final prefs = await SharedPreferences.getInstance();
            final hasSeenWelcome = prefs.getBool('welcome_seen') ?? false;
            
            if (!hasSeenWelcome) {
              print('Navigating to welcome screen');
              context.go('/welcome');
              return;
            }
          }
          
          print('Navigating to home');
          context.go('/home');
        } else {
          print('Navigating to profile setup');
          context.go('/profile_setup');
        }
      }
    } catch (e) {
      print('Error checking profile: $e');
      // On error, assume no profile exists
      if (mounted) {
        context.go('/profile_setup');
      }
    }
  }

  void _generatePassword() {
    final generatedPassword = PasswordValidator.generateStrongPassword();
    _passwordController.text = generatedPassword;
    _confirmPasswordController.text = generatedPassword;
    setState(() {
      _showPasswordRequirements = true;
    });
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check terms acceptance for signup
    if (!_isLogin && !_acceptTerms) {
      setState(() {
        _errorMessage = 'Please accept the Terms of Service and Privacy Policy';
      });
      return;
    }

    // Check password strength for signup
    if (!_isLogin) {
      final validation = PasswordValidator.validatePassword(_passwordController.text);
      if (!validation.isValid) {
        setState(() {
          _errorMessage = 'Please fix password requirements before continuing';
          _showPasswordRequirements = true;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential;
      
      if (_isLogin) {
        print('Attempting login...');
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        print('Attempting registration...');
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // Send welcome email for new users
        if (userCredential.user != null) {
          await EmailService.sendWelcomeEmail(
            userEmail: userCredential.user!.email!,
            userName: userCredential.user!.email!.split('@')[0], // Use email prefix as temporary name
            userId: userCredential.user!.uid,
          );
          
          // Send email verification
          await EmailService.sendEmailVerificationReminder(userCredential.user!);
          
          // Show success message for new signup
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.email, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Welcome! Please check your email for verification and welcome message.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        }
      }
      
      print('Authentication successful for: ${userCredential.user?.email}');
      
      // Handle successful authentication
      if (mounted && userCredential.user != null) {
        await _handleAuthenticatedUser(userCredential.user!, isExistingSession: false);
      }
      
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e);
      });
    } catch (e) {
      print('General Error: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if we're still checking existing auth
    if (!_hasCheckedAuth) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking authentication...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Sign Up'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // App Logo/Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.mosque,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  _isLogin ? 'Welcome Back!' : 'Join Our Community!',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin 
                      ? 'Sign in to continue your spiritual journey'
                      : 'Create an account to begin your Islamic journey',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: _isLogin ? null : 'We\'ll send you important updates here',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLogin)
                          IconButton(
                            icon: const Icon(Icons.auto_awesome),
                            onPressed: _generatePassword,
                            tooltip: 'Generate Strong Password',
                          ),
                        IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: !_isLogin ? 'Tap the star to generate a strong password' : null,
                  ),
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  onChanged: (value) {
                    if (!_isLogin) {
                      setState(() {
                        _showPasswordRequirements = value.isNotEmpty;
                      });
                    }
                  },
                  onTap: () {
                    if (!_isLogin) {
                      setState(() {
                        _showPasswordRequirements = true;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (_isLogin) {
                      return null; // For login, just check if not empty
                    }
                    // For signup, check password strength
                    final validation = PasswordValidator.validatePassword(value);
                    if (!validation.isValid) {
                      return 'Password does not meet requirements';
                    }
                    return null;
                  },
                ),

                // Password Strength Widget (for signup only)
                if (!_isLogin && _showPasswordRequirements)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PasswordStrengthWidget(
                      password: _passwordController.text,
                      showRequirements: true,
                      onGeneratePassword: _generatePassword,
                    ),
                  ),

                const SizedBox(height: 20),

                // Confirm Password Field (for signup only)
                if (!_isLogin)
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (!_isLogin) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                      }
                      return null;
                    },
                  ),

                if (!_isLogin) const SizedBox(height: 20),

                // Terms and Conditions (for signup only)
                if (!_isLogin)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CheckboxListTile(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                      title: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                if (!_isLogin) const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Submit Button
                _isLoading
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Please wait...'),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isLogin ? 'Login' : 'Create Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Switch between Login/Signup
                TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                      _showPasswordRequirements = false;
                      _acceptTerms = false;
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  child: Text(_isLogin
                      ? 'Don\'t have an account? Sign Up'
                      : 'Already have an account? Login'),
                ),

                // Forgot Password (for login only)
                if (_isLogin)
                  TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),

                const SizedBox(height: 20),

                // Email notification info (for signup only)
                if (!_isLogin)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You\'ll receive a welcome email and verification link after signup.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address and we\'ll send you a password reset link.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email address')),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                // Send confirmation email
                await EmailService.sendPasswordResetConfirmation(
                  userEmail: email,
                  userName: email.split('@')[0],
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}