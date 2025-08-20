import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  //constants for theming
  static const double _borderRadius = 16.0;
  static const double _cardPadding = 20.0;
  static const double _spacing = 16.0;
  static const double _cardMargin = 20.0;

  //text styles
  static const TextStyle _headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle _nameStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle _subtitleStyle = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );

  //state variables
  String userName = 'Mia';
  bool isRecording = false;
  bool isProcessing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializePulseAnimation();
  }

  void _initializePulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      isRecording = true;
      isProcessing = false;
    });
    _pulseController.repeat(reverse: true);

    //simulate recording for 3 seconds, then processing
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isRecording = false;
          isProcessing = true;
        });
        _pulseController.stop();

        //simulate processing for 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              isProcessing = false;
            });
            _showSuccessMessage();
          }
        });
      }
    });
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice sample recorded successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Helper to Build Consistent Card Container ---
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      margin: const EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- Helper to Build Name Display Card ---
  Widget _buildNameDisplayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Your Name: "$userName"',
            style: _nameStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'AI will recognize when someone calls your name',
            style: _subtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Helper to Build Recording Section ---
  Widget _buildRecordingSection() {
    return _buildCard(
      child: Column(
        children: [
          const Text('Improve Recognition', style: _titleStyle),
          const SizedBox(height: 32),

          //Recording button with animation
          GestureDetector(
            onTap: isRecording || isProcessing ? null : _startRecording,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isRecording
                        ? Colors.red.withOpacity(0.1 + (_pulseController.value * 0.3))
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRecording ? Colors.red : Colors.blue.shade200,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 48,
                    color: isRecording ? Colors.red : Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          //Status text
          Text(
            _getStatusText(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          // Processing indicator
          if (isProcessing) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Processing audio',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(3, (index) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusText() {
    if (isRecording) {
      return 'Recording... Speak your name clearly';
    } else if (isProcessing) {
      return 'Processing your voice sample...';
    } else {
      return 'Tap to record someone saying your name';
    }
  }

  // --- Helper to Build Training Tips Section ---
  Widget _buildTrainingTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Training Tips', style: _titleStyle),
        const SizedBox(height: 16),

        _buildTipItem('Ask different people to say your name'),
        _buildTipItem('Record in various noise levels'),
        _buildTipItem('Include whispers and loud calls'),
        _buildTipItem('More samples = better accuracy'),
      ],
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          //Content section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  _buildNameDisplayCard(),
                  _buildRecordingSection(),
                  _buildTrainingTipsSection(),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}