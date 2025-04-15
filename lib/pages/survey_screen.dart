import 'package:flutter/material.dart';
import 'package:focus/services/survey_service.dart';
import 'package:focus/services/firebase_auth_methods.dart';
import 'package:focus/pages/home_screen.dart'; // Add this import for FocusFlowHome
import 'package:focus/widgets/navigation_wrapper.dart';
import 'package:lottie/lottie.dart';

class SurveyScreen extends StatefulWidget {
  final String userId;

  const SurveyScreen({required this.userId, Key? key}) : super(key: key);

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final SurveyService _surveyService = SurveyService();
  final AuthService _authService = AuthService();
  late PageController _pageController;
  List<Map<String, dynamic>> questions = [];
  Map<String, String> answers = {};
  int currentPage = 0;
  bool isLoading = true;
  final _usernameController = TextEditingController();
  bool _isSettingUsername = false;
  String? errorMessage;
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final fetchedQuestions = await _surveyService.getSurveyQuestions();
      if (mounted) {
        setState(() {
          if (fetchedQuestions.isEmpty) {
            errorMessage = "No survey questions available.";
          } else {
            questions = fetchedQuestions;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Error loading survey: $e";
          isLoading = false;
        });
      }
    }
  }

  void _onOptionSelected(
      String questionId, String questionText, String option) {
    if (mounted) {
      setState(() {
        answers[questionId] = option;
      });
    }
    _surveyService.saveAnswer(widget.userId, questionId, questionText, option);
  }

  void _nextPage() {
    if (currentPage < questions.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSurveyAndSetUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() => _isSettingUsername = true);
    try {
      final usernameSuccess =
          await _authService.setUsername(_usernameController.text.trim());
      if (usernameSuccess) {
        await _surveyService.completeSurvey(widget.userId);
        setState(() => _showAnimation = true);
      } else {
        throw Exception("Username taken or error occurred");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSettingUsername = false;
          errorMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _onAnimationComplete() {
    if (mounted) {
      setState(() {
        _isSettingUsername = false;
        _showAnimation = false;
      });
      // Redirect to FocusFlowHome after animation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body:
            Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Container(color: Colors.blue.withOpacity(0.03)),
                );
              },
            ),
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      if (mounted) setState(() => currentPage = index);
                    },
                    itemCount: questions.length + 1,
                    itemBuilder: (context, index) {
                      if (index < questions.length) {
                        final question = questions[index];
                        return SurveyPage(
                          questionId: question['id'],
                          questionText: question['text'],
                          options: List<String>.from(question['options']),
                          selectedOption: answers[question['id']],
                          onOptionSelected: _onOptionSelected,
                        );
                      } else {
                        return UsernamePage(controller: _usernameController);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: screenHeight * 0.03,
                  ),
                  child: Center(
                    child: currentPage < questions.length
                        ? (answers[questions[currentPage]['id']] != null
                            ? _buildButton('Continue', _nextPage)
                            : const SizedBox.shrink())
                        : _buildButton(
                            _isSettingUsername ? 'Saving...' : 'Finish',
                            _isSettingUsername || _showAnimation
                                ? null
                                : _finishSurveyAndSetUsername,
                          ),
                  ),
                ),
              ],
            ),
            if (_showAnimation)
              Center(
                child: Lottie.asset(
                  'assets/animations/onboarding_animation.json',
                  width: screenWidth * 0.8,
                  height: screenHeight * 0.5,
                  fit: BoxFit.contain,
                  repeat: false,
                  onLoaded: (composition) {
                    debugPrint(
                        "Animation duration: ${composition.duration.inMilliseconds}ms");
                    Future.delayed(composition.duration, _onAnimationComplete);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback? onPressed) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 1, 58, 105),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              blurRadius: 400,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.3,
          vertical: screenHeight * 0.025,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}

class SurveyPage extends StatelessWidget {
  final String questionId;
  final String questionText;
  final List<String> options;
  final String? selectedOption;
  final Function(String, String, String) onOptionSelected;

  const SurveyPage({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.selectedOption,
    required this.onOptionSelected,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.06,
        vertical: screenHeight * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.05),
          Text(
            questionText,
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.blue.withOpacity(0.5), blurRadius: 8),
              ],
            ),
            textAlign: TextAlign.left,
          ),
          SizedBox(height: screenHeight * 0.04),
          Expanded(
            child: ListView(
              children: options
                  .map((option) => Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015),
                        child: GestureDetector(
                          onTap: () => onOptionSelected(
                              questionId, questionText, option),
                          child: Container(
                            height: screenHeight * 0.1,
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedOption == option
                                    ? Colors.blueAccent
                                    : Colors.grey[900]!,
                                width: selectedOption == option ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: selectedOption == option
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.w400,
                                  color: selectedOption == option
                                      ? Colors.blueAccent
                                      : Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class UsernamePage extends StatelessWidget {
  final TextEditingController controller;

  const UsernamePage({required this.controller, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.06,
        vertical: screenHeight * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.05),
          Text(
            "What should we call you?",
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.blue.withOpacity(0.5), blurRadius: 8),
              ],
            ),
            textAlign: TextAlign.left,
          ),
          SizedBox(height: screenHeight * 0.04),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter your username",
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
