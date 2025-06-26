import 'package:flutter/material.dart';
import 'dart:math';

class TransactionSecurityTestPage extends StatefulWidget {
  const TransactionSecurityTestPage({super.key});

  @override
  State<TransactionSecurityTestPage> createState() => _TransactionSecurityTestPageState();
}

class _TransactionSecurityTestPageState extends State<TransactionSecurityTestPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  String _result = '';
  bool _isLoading = false;

  // Simulated current time
  final String _currentTime = '2025-06-22 15:26:42';
  final String _currentUser = 'ProthamDT2004';
  
  @override
  void initState() {
    super.initState();
    _timeController.text = _currentTime;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _categoryController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _runTest() {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    // Simulate a network request
    Future.delayed(const Duration(seconds: 1), () {
      // Generate a random risk score between 0 and 100
      final riskScore = Random().nextDouble() * 100;
      final amount = double.tryParse(_amountController.text) ?? 0;
      
      String resultText;
      Color resultColor;
      
      if (amount > 10000) {
        resultText = 'HIGH RISK TRANSACTION DETECTED (Score: ${riskScore.toStringAsFixed(2)})\n'
            'Amount exceeds typical spending pattern\n'
            'Additional verification recommended';
        resultColor = Colors.red;
      } else if (riskScore > 70) {
        resultText = 'POTENTIAL RISK DETECTED (Score: ${riskScore.toStringAsFixed(2)})\n'
            'Unusual transaction pattern identified\n'
            'Verification may be required';
        resultColor = Colors.orange;
      } else {
        resultText = 'TRANSACTION APPEARS LEGITIMATE (Score: ${riskScore.toStringAsFixed(2)})\n'
            'No anomalies detected\n'
            'Transaction can proceed';
        resultColor = Colors.green;
      }
      
      setState(() {
        _isLoading = false;
        _result = resultText;
        
        // Log the test transaction in the debug console
        debugPrint('TRANSACTION TEST [${_timeController.text}] - '
            'Amount: ${_amountController.text}, '
            'Merchant: ${_merchantController.text}, '
            'Category: ${_categoryController.text}, '
            'Risk Score: ${riskScore.toStringAsFixed(2)}');
      });
      
      // Show a snackbar with the result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultText.split('\n')[0]),
            backgroundColor: resultColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Security Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Text('Current User: $_currentUser'),
                      Text('Current Time (UTC): $_currentTime'),
                      Text('Environment: Debug Mode'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Test Transaction Anomaly Detection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter transaction details to test if the security system identifies it as anomalous:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Time (UTC)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _runTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Test Transaction Security'),
                ),
              ),
               if (_result.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _result.contains('LEGITIMATE')
                        ? Colors.green.withOpacity(0.1)
                        : _result.contains('POTENTIAL')
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _result.contains('LEGITIMATE')
                          ? Colors.green
                          : _result.contains('POTENTIAL')
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analysis Result',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Text(
                        _result,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Note: This is a simulated test. In production, the system will use AI to analyze user transaction patterns.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}