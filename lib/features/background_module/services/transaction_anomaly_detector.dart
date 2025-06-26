// ignore_for_file: unused_import

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';

/// Simple transaction anomaly detection service
class TransactionAnomalyDetector {
  static final TransactionAnomalyDetector _instance = TransactionAnomalyDetector._internal();
  factory TransactionAnomalyDetector() => _instance;
  TransactionAnomalyDetector._internal();

  // Store recent transactions for pattern analysis
  final List<Transaction> _recentTransactions = [];
  final List<TransactionAnomaly> _detectedAnomalies = [];

  // Stream for real-time anomaly notifications
  final _anomalyStreamController = StreamController<TransactionAnomaly>.broadcast();
  Stream<TransactionAnomaly> get anomalyStream => _anomalyStreamController.stream;

  /// Analyze a transaction for anomalies
  Future<List<TransactionAnomaly>> analyzeTransaction(Transaction transaction) async {
    final anomalies = <TransactionAnomaly>[];

    try {
      // Add transaction to recent list
      _recentTransactions.add(transaction);
      
      // Keep only last 100 transactions for analysis
      if (_recentTransactions.length > 100) {
        _recentTransactions.removeAt(0);
      }

      // Run various anomaly checks
      final unusualAmountAnomaly = await _checkUnusualAmount(transaction);
      if (unusualAmountAnomaly != null) anomalies.add(unusualAmountAnomaly);

      final timeBasedAnomaly = await _checkUnusualTime(transaction);
      if (timeBasedAnomaly != null) anomalies.add(timeBasedAnomaly);

      final frequencyAnomaly = await _checkHighFrequency(transaction);
      if (frequencyAnomaly != null) anomalies.add(frequencyAnomaly);

      final locationAnomaly = await _checkUnusualLocation(transaction);
      if (locationAnomaly != null) anomalies.add(locationAnomaly);

      final deviceAnomaly = await _checkDeviceChange(transaction);
      if (deviceAnomaly != null) anomalies.add(deviceAnomaly);

      // Store detected anomalies
      _detectedAnomalies.addAll(anomalies);

      // Broadcast anomalies
      for (final anomaly in anomalies) {
        _anomalyStreamController.add(anomaly);
      }

      debugPrint('Transaction ${transaction.id} analyzed: ${anomalies.length} anomalies detected');

    } catch (e) {
      debugPrint('Error analyzing transaction: $e');
    }

    return anomalies;
  }

  /// Check for unusual transaction amounts
  Future<TransactionAnomaly?> _checkUnusualAmount(Transaction transaction) async {
    if (_recentTransactions.length < 10) return null;

    // Calculate average amount for similar transaction types
    final similarTransactions = _recentTransactions
        .where((t) => t.type == transaction.type && t.id != transaction.id)
        .toList();

    if (similarTransactions.isEmpty) return null;

    final averageAmount = similarTransactions
        .map((t) => t.amount)
        .reduce((a, b) => a + b) / similarTransactions.length;

    // Check if current amount is significantly higher than average
    final threshold = averageAmount * 3; // 3x average is suspicious
    
    if (transaction.amount > threshold) {
      return TransactionAnomaly(
        id: 'amount_${transaction.id}',
        transactionId: transaction.id,
        riskLevel: transaction.amount > threshold * 2 
            ? TransactionRiskLevel.high 
            : TransactionRiskLevel.medium,
        anomalyType: 'Unusual Amount',
        description: 'Transaction amount (₹${transaction.amount.toStringAsFixed(2)}) is significantly higher than your average (₹${averageAmount.toStringAsFixed(2)})',
        detectedAt: DateTime.now(),
        details: {
          'amount': transaction.amount,
          'averageAmount': averageAmount,
          'threshold': threshold,
        },
      );
    }

    return null;
  }

  /// Check for unusual transaction times
  Future<TransactionAnomaly?> _checkUnusualTime(Transaction transaction) async {
    final hour = transaction.timestamp.hour;
    
    // Flag transactions between 11 PM and 6 AM as potentially suspicious
    if (hour >= 23 || hour <= 6) {
      return TransactionAnomaly(
        id: 'time_${transaction.id}',
        transactionId: transaction.id,
        riskLevel: TransactionRiskLevel.medium,
        anomalyType: 'Unusual Time',
        description: 'Transaction made during unusual hours (${hour}:${transaction.timestamp.minute.toString().padLeft(2, '0')})',
        detectedAt: DateTime.now(),
        details: {
          'hour': hour,
          'minute': transaction.timestamp.minute,
        },
      );
    }

    return null;
  }

  /// Check for high frequency transactions
  Future<TransactionAnomaly?> _checkHighFrequency(Transaction transaction) async {
    final now = DateTime.now();
    final lastHour = now.subtract(Duration(hours: 1));
    
    // Count transactions in the last hour
    final recentCount = _recentTransactions
        .where((t) => t.timestamp.isAfter(lastHour) && t.accountId == transaction.accountId)
        .length;

    if (recentCount > 5) { // More than 5 transactions per hour is suspicious
      return TransactionAnomaly(
        id: 'frequency_${transaction.id}',
        transactionId: transaction.id,
        riskLevel: recentCount > 10 
            ? TransactionRiskLevel.high 
            : TransactionRiskLevel.medium,
        anomalyType: 'High Frequency',
        description: 'High number of transactions ($recentCount) in the last hour',
        detectedAt: DateTime.now(),
        details: {
          'transactionCount': recentCount,
          'timeWindow': '1 hour',
        },
      );
    }

    return null;
  }

  /// Check for unusual locations (simplified for emulator)
  Future<TransactionAnomaly?> _checkUnusualLocation(Transaction transaction) async {
    // For emulator testing, we'll simulate location checks
    // In production, you'd use actual geolocation services
    
    final prefs = await SharedPreferences.getInstance();
    final lastKnownLocation = prefs.getString('last_transaction_location');
    
    if (lastKnownLocation != null && lastKnownLocation != transaction.location) {
      // Save current location
      await prefs.setString('last_transaction_location', transaction.location);
      
      return TransactionAnomaly(
        id: 'location_${transaction.id}',
        transactionId: transaction.id,
        riskLevel: TransactionRiskLevel.medium,
        anomalyType: 'Location Change',
        description: 'Transaction from a different location than usual',
        detectedAt: DateTime.now(),
        details: {
          'currentLocation': transaction.location,
          'previousLocation': lastKnownLocation,
        },
      );
    }

    // Save location for future comparisons
    await prefs.setString('last_transaction_location', transaction.location);
    return null;
  }

  /// Check for device changes
  Future<TransactionAnomaly?> _checkDeviceChange(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnownDevice = prefs.getString('last_transaction_device');
    
    if (lastKnownDevice != null && lastKnownDevice != transaction.deviceInfo) {
      // Save current device
      await prefs.setString('last_transaction_device', transaction.deviceInfo);
      
      return TransactionAnomaly(
        id: 'device_${transaction.id}',
        transactionId: transaction.id,
        riskLevel: TransactionRiskLevel.high,
        anomalyType: 'Device Change',
        description: 'Transaction from a different device than usual',
        detectedAt: DateTime.now(),
        details: {
          'currentDevice': transaction.deviceInfo,
          'previousDevice': lastKnownDevice,
        },
      );
    }

    // Save device for future comparisons
    await prefs.setString('last_transaction_device', transaction.deviceInfo);
    return null;
  }

  /// Get all detected anomalies
  List<TransactionAnomaly> get detectedAnomalies => List.unmodifiable(_detectedAnomalies);

  /// Get recent transactions
  List<Transaction> get recentTransactions => List.unmodifiable(_recentTransactions);

  /// Clear old data
  Future<void> clearOldData() async {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    
    _recentTransactions.removeWhere((t) => t.timestamp.isBefore(thirtyDaysAgo));
    _detectedAnomalies.removeWhere((a) => a.detectedAt.isBefore(thirtyDaysAgo));
  }

  /// Dispose resources
  void dispose() {
    _anomalyStreamController.close();
  }
}