import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  //Animation controller for the scanning spinner
  late AnimationController _animationController;
  bool isScanning = true;
  bool deviceFound = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    //Simulate device discovery after a second
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        isScanning = false;
        deviceFound = true;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  //Helper to Build Scanning Card
  Widget buildScanningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          //Animated loading spinner
          RotationTransition(
            turns: _animationController,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: Colors.blue,
                  width: 3,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          //Scanning text
          const Expanded(
            child: Text(
              'Scanning for hearing aid watches...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Helper to Build Device Found Card
  Widget buildDeviceFoundCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          //Watch icon with blue background
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(32.0),
            ),
            child: const Icon(
              Icons.watch,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 20),

          //Device info
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hearing Aid Watch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 16,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Available to pair',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //Helper to Build Bottom Instructions
  Widget buildBottomInstructions() {
    return Column(
      children: [
        //Signal icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(32.0),
          ),
          child: Icon(
            Icons.signal_cellular_alt,
            color: Colors.grey.shade500,
            size: 32,
          ),
        ),

        const SizedBox(height: 20),

        //Instruction text
        Text(
          'Make sure your watch is in\npairing mode',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          //Blue header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connect Watch',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                  onPressed: () {
                    //Handle settings tap
                  },
                ),
              ],
            ),
          ),

          //Content section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  //Scanning or Device Found Card
                  if (isScanning) buildScanningCard(),
                  if (deviceFound) buildDeviceFoundCard(),

                  const Spacer(),

                  //Bottom instructions
                  buildBottomInstructions(),

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