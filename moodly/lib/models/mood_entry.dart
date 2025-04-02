import 'package:flutter/material.dart';
import 'dart:convert'; // Import for json encoding/decoding

class MoodEntry {
  final int? id; // Add nullable ID field
  final DateTime date;
  final String mood; // Could be an enum later
  final String? notes;
  // Potential future fields: activities, triggers, sleep duration, etc.

  MoodEntry({
    this.id, // Make id optional in constructor
    required this.date,
    required this.mood,
    this.notes,
  });

  // Method to convert a MoodEntry instance to a Map (for JSON encoding)
  Map<String, dynamic> toJson() => {
        'id': id, // Include id (can be null)
        'date': date.toIso8601String(), // Store date as ISO 8601 string
        'mood': mood,
        'notes': notes,
      };

  // Factory constructor to create a MoodEntry instance from a Map (from JSON)
  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      // Expect 'entry_date' from API (MySQL format: YYYY-MM-DD HH:MM:SS)
      final dateString = json['entry_date'] as String;
      final parts = dateString.split(' ');
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      
      parsedDate = DateTime(
          int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]),
          int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2]),
      ).toLocal();
    } catch (e) {
      print("Error parsing date from JSON: ${json['entry_date']}, Error: $e");
      // Fallback or throw error? Using current time as fallback for now.
      parsedDate = DateTime.now(); 
    }

    return MoodEntry(
      id: json['id'] as int?,
      date: parsedDate, // Use the parsed date
      mood: json['mood'] as String,
      notes: json['notes'] as String?,
    );
  }

  // Static method to encode a list of MoodEntry objects to a JSON string
  static String encode(List<MoodEntry> entries) => json.encode(
        entries
            .map<Map<String, dynamic>>((entry) => entry.toJson())
            .toList(),
      );

  // Static method to decode a JSON string into a list of MoodEntry objects
  static List<MoodEntry> decode(String entries) =>
      (json.decode(entries) as List<dynamic>)
          .map<MoodEntry>((item) => MoodEntry.fromJson(item as Map<String, dynamic>))
          .toList();
} 