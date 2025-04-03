import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import '../models/mood_entry.dart'; // Assuming model is in models folder
import 'package:moodly/services/api_service.dart'; // Use ApiService
import 'package:intl/intl.dart'; // For date formatting
import 'package:http/http.dart' as http; // Import http

class AddMoodScreen extends StatefulWidget {
  // Optional: Receive entry for editing
  final MoodEntry? entryToEdit;
  
  const AddMoodScreen({super.key, this.entryToEdit});

  @override
  State<AddMoodScreen> createState() => _AddMoodScreenState();
}

class _AddMoodScreenState extends State<AddMoodScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMood; // Use nullable for initial state
  DateTime _selectedDate = DateTime.now(); // Allow date selection
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool get _isEditing => widget.entryToEdit != null;

  // Enhanced mood options with icons and colors (match main screen)
  // Using a Map for easier access
  final Map<String, Map<String, dynamic>> _moodOptions = {
    'Feliz': {'icon': Icons.sentiment_very_satisfied, 'color': Colors.green[400]!},
    'Triste': {'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.blue[400]!},
    'Neutro': {'icon': Icons.sentiment_neutral, 'color': Colors.grey[500]!},
    'Ansioso': {'icon': Icons.sentiment_dissatisfied, 'color': Colors.orange[400]!},
    'Com Raiva': {'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.red[400]!},
    'Animado': {'icon': Icons.sentiment_satisfied_alt, 'color': Colors.purple[300]!},
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // Pre-fill form if editing
      _selectedMood = widget.entryToEdit!.mood;
      _selectedDate = widget.entryToEdit!.date;
      _notesController.text = widget.entryToEdit!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // Allow past dates
      lastDate: DateTime.now(), // Only up to today
    );
    if (picked != null && picked != _selectedDate) {
      // Combine with time selection if needed, or keep current time
      final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedDate)
      );
      if (pickedTime != null) {
         setState(() {
           _selectedDate = DateTime(
             picked.year, picked.month, picked.day, 
             pickedTime.hour, pickedTime.minute
            );
        });
      }
    }
  }

  Future<void> _submitForm() async {
    // Validate mood selection
    if (_selectedMood == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Por favor, selecione um humor.')),
       );
       return;
    }
    
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final moodData = {
        'mood': _selectedMood!,
        'notes': _notesController.text.trim(),
        // Send date in ISO 8601 format (UTC is standard for APIs)
        'entry_date': _selectedDate.toUtc().toIso8601String(), 
      };

      String message = 'Erro desconhecido.';
      bool success = false;

      try {
        http.Response response;
        if (_isEditing) {
          // --- Update API Call --- 
          print("Updating entry ID: ${widget.entryToEdit!.id}");
          response = await ApiService.updateMood(widget.entryToEdit!.id!, moodData)
                          .timeout(const Duration(seconds: 10));
          message = 'Erro ao atualizar.';
        } else {
          // --- Add API Call --- 
          response = await ApiService.addMood(moodData)
                          .timeout(const Duration(seconds: 10));
           message = 'Erro ao adicionar.';
        }

        final responseData = json.decode(response.body);

        if ((response.statusCode == 200 || response.statusCode == 201) && responseData['success'] == true) {
            success = true;
            message = _isEditing ? 'Humor atualizado!' : 'Humor adicionado!';
        } else {
          message = responseData['message'] ?? message;
          print("API Error (${response.statusCode}): ${response.body}");
        }
      } catch (error) {
         print("${_isEditing ? 'Update' : 'Add'} Mood API Error: $error");
         message = 'Erro conexão.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      if (success) {
         Navigator.pop(context, true); // Return true to signal refresh needed
      } else {
          setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Humor' : 'Como você está?'),
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // --- Date Selection --- 
              Text('Data e Hora:', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                 onTap: () => _selectDate(context),
                 child: InputDecorator(
                   decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         DateFormat('EEEE, dd/MM/yyyy HH:mm', 'pt_BR').format(_selectedDate),
                         style: textTheme.titleMedium,
                        ),
                       const Icon(Icons.calendar_today, color: Colors.grey),
                     ],
                   ),
                 ),
              ),
              const SizedBox(height: 24),

              // --- Mood Selection (Visual Buttons) --- 
              Text('Selecione seu humor:', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10.0, // Horizontal space
                runSpacing: 10.0, // Vertical space
                alignment: WrapAlignment.center,
                children: _moodOptions.entries.map((entry) {
                  final moodName = entry.key;
                  final moodData = entry.value;
                  final bool isSelected = _selectedMood == moodName;
                  final Color color = moodData['color'];
                  final IconData icon = moodData['icon'];

                  return ElevatedButton.icon(
                    icon: Icon(icon, color: isSelected ? Colors.white : color), 
                    label: Text(moodName,
                               style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.w500)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? color : color.withOpacity(0.1),
                      foregroundColor: isSelected ? Colors.white : color, // Text/Icon color on hover/splash
                      elevation: isSelected ? 2.0 : 0.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        side: BorderSide(color: isSelected ? color : color.withOpacity(0.5), width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedMood = moodName;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- Notes --- 
              Text('Notas (opcional):', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Pensamentos, eventos, contexto...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 30),

              // --- Submit Button --- 
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEditing ? 'Atualizar Humor' : 'Salvar Humor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 