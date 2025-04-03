import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moodly/models/mood_entry.dart';
import 'package:moodly/screens/add_mood_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:moodly/screens/login_screen.dart';
import 'package:moodly/services/api_service.dart';
import 'package:moodly/screens/reports_screen.dart';

// HomeScreen definition moved here from main.dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MoodEntry> _allMoodEntries = []; // Store all fetched entries
  List<MoodEntry> _filteredMoodEntries = []; // Entries currently displayed
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _selectedMoodFilters = {}; // Set to store selected moods for filtering

  // Mood colors reused from ReportsScreen (consider moving to a shared place)
   final Map<String, Color> _moodColors = {
    'Feliz': Colors.green[400]!,
    'Triste': Colors.blue[400]!,
    'Neutro': Colors.grey[500]!,
    'Ansioso': Colors.orange[400]!,
    'Com Raiva': Colors.red[400]!,
    'Animado': Colors.purple[300]!,
  };

   Color _getMoodColor(String mood) {
     return _moodColors[mood] ?? Colors.grey[500]!;
   }

  @override
  void initState() {
    super.initState();
    _loadMoodEntriesFromApi();
  }

  // Load entries from Backend API
  Future<void> _loadMoodEntriesFromApi() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await ApiService.getMoods().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        print("Raw API Response (Get Moods): ${response.body}");
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          final entries = data.map((item) {
             try { return MoodEntry.fromJson(item); }
             catch(e) { print("Error processing API item: $item, Error: $e"); return null; }
           }).whereType<MoodEntry>().toList();

          setState(() {
            _allMoodEntries = entries; // Store all entries
            _applyFilters(); // Apply current filters (initially none)
            _isLoading = false;
          });
        } else { throw Exception(responseData['message'] ?? 'API Error'); }
      } else if (response.statusCode == 401) { _handleUnauthorized(); }
      else { throw Exception('Status: ${response.statusCode}'); }
    } catch (error) {
      print("Load Moods API Error: $error");
      if (mounted) { setState(() { _errorMessage = 'Erro ao buscar.'; _isLoading = false; }); }
    }
  }

  // Apply filters to the list
  void _applyFilters() {
    if (_selectedMoodFilters.isEmpty) {
       // No filter selected, show all
       _filteredMoodEntries = List.from(_allMoodEntries);
    } else {
      _filteredMoodEntries = _allMoodEntries
          .where((entry) => _selectedMoodFilters.contains(entry.mood))
          .toList();
    }
    // No need for setState here if called within a setState or after initial load
  }

  void _navigateToAddEditScreen([MoodEntry? entry]) async {
    final bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMoodScreen(entryToEdit: entry),
      ),
    );

    if (shouldRefresh == true) {
      _loadMoodEntriesFromApi(); // Reload all and re-apply filters
    }
  }
  
  Future<void> _deleteEntry(int id, int index) async {
    // Important: Operate on _filteredMoodEntries for index, but find in _allMoodEntries for removal
    final removedFilteredEntry = _filteredMoodEntries.removeAt(index);
    final originalIndexInAll = _allMoodEntries.indexWhere((e) => e.id == removedFilteredEntry.id);
    MoodEntry? removedOriginalEntry; 
    if(originalIndexInAll != -1) {
       removedOriginalEntry = _allMoodEntries.removeAt(originalIndexInAll);
    }
    setState(() {}); // Update UI after removing from filtered list

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${removedFilteredEntry.mood} removido.'),
          action: SnackBarAction(
             label: 'DESFAZER',
             onPressed: () {
                // Re-insert into both lists if undone
               if(removedOriginalEntry != null && originalIndexInAll != -1) {
                  _allMoodEntries.insert(originalIndexInAll, removedOriginalEntry);
               }
               // Re-apply filters to potentially show the undone item again
               setState(() => _applyFilters()); 
             },
          ),
       ),
    );

    await Future.delayed(const Duration(seconds: 3));

    // Check if the item is still removed from the *main* list before API call
    if (removedOriginalEntry != null && !_allMoodEntries.contains(removedOriginalEntry)) { 
        try {
          final response = await ApiService.deleteMood(id).timeout(const Duration(seconds: 10));
          if (!mounted) return;
          if (response.statusCode == 200) {
             print("Entry ID $id deleted from backend.");
          } else if (response.statusCode == 401) {
             _handleUnauthorized();
          } else {
             print("Failed to delete ID $id (${response.statusCode}). Re-inserting.");
             // Re-insert on backend failure
             if(originalIndexInAll != -1) {
                 _allMoodEntries.insert(originalIndexInAll, removedOriginalEntry);
             }
             setState(() => _applyFilters()); // Update UI
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Erro ao deletar ${removedOriginalEntry.mood}.')),
             );
          }
        } catch (error) {
           print("Delete API Error: $error");
           if (mounted) {
             // Re-insert on network failure
             if(originalIndexInAll != -1) {
                  _allMoodEntries.insert(originalIndexInAll, removedOriginalEntry);
             }
             setState(() => _applyFilters()); // Update UI
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Erro conexão ao deletar ${removedOriginalEntry.mood}.')),
             );
          }
        }
      }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print("Token removed, logging out.");
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()), 
        (Route<dynamic> route) => false,
      );
    }
  }

  void _handleUnauthorized() {
     if (mounted) {
       _logout();
     }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
      primary: Colors.deepPurple[300]!,
      secondary: Colors.teal[200]!,
      background: Colors.grey[50]!,
    );
    final TextTheme textTheme = Theme.of(context).textTheme.apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
             icon: const Icon(Icons.bar_chart),
             tooltip: 'Relatórios',
             onPressed: () {
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => const ReportsScreen()),
                 );
             },
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: _logout)
        ],
        elevation: 2.0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBodyContent(colorScheme, textTheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        tooltip: 'Add Humor',
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_reaction_outlined),
        elevation: 4.0,
      ),
    );
  }

  Widget _buildFilterChips() {
     if (_allMoodEntries.isEmpty && !_isLoading) return const SizedBox.shrink(); 

    return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
       child: Wrap(
         spacing: 8.0,
         runSpacing: 4.0,
         children: _moodColors.keys.map((mood) {
           final bool isSelected = _selectedMoodFilters.contains(mood);
           final color = _getMoodColor(mood);
           return FilterChip(
             label: Text(mood),
             labelStyle: TextStyle(
                color: isSelected ? Colors.white : color.withOpacity(0.9),
                fontWeight: FontWeight.w500
             ),
             selected: isSelected,
             onSelected: (bool selected) {
               setState(() {
                 if (selected) {
                   _selectedMoodFilters.add(mood);
                 } else {
                   _selectedMoodFilters.remove(mood);
                 }
                 _applyFilters(); // Re-apply filters when selection changes
               });
             },
             backgroundColor: color.withOpacity(0.1),
             selectedColor: color, 
             checkmarkColor: Colors.white,
             side: BorderSide(color: color.withOpacity(0.4)),
             shape: StadiumBorder(),
           );
         }).toList(),
       ),
     );
  }

  Widget _buildBodyContent(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
       return Center(
          child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                   const SizedBox(height: 16),
                   Text(_errorMessage!, style: textTheme.titleMedium, textAlign: TextAlign.center),
                   const SizedBox(height: 20),
                   ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      onPressed: _loadMoodEntriesFromApi,
                   )
                ],
             ),
          ),
       );
    }
    if (_filteredMoodEntries.isEmpty) { 
      final message = _selectedMoodFilters.isNotEmpty
          ? 'Nenhuma entrada encontrada para os filtros selecionados.'
          : 'Seu diário de humor está vazio';
       final icon = _selectedMoodFilters.isNotEmpty 
           ? Icons.filter_alt_off_outlined 
           : Icons.cloud_off_outlined;

      return Center(
         child: Padding(
           padding: const EdgeInsets.all(32.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(icon, size: 80, color: Colors.grey[400]),
               const SizedBox(height: 20),
               Text(
                 message,
                 style: textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                 textAlign: TextAlign.center,
               ),
                if (_selectedMoodFilters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextButton(
                      onPressed: () {
                         setState(() {
                           _selectedMoodFilters.clear();
                           _applyFilters();
                         });
                      },
                      child: const Text('Limpar Filtros'),
                    ),
                  )
             ],
           ),
         ),
       );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 12.0),
        itemCount: _filteredMoodEntries.length, 
        itemBuilder: (context, index) {
          final entry = _filteredMoodEntries[index];
          final moodColor = _getMoodColor(entry.mood);

          return Dismissible(
            key: ValueKey(entry.id ?? entry.date),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red[400],
              padding: const EdgeInsets.only(right: 20.0),
              alignment: Alignment.centerRight,
              child: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Confirmar Exclusão"),
                    content: Text("Tem certeza que deseja apagar a entrada de '${entry.mood}'?"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("CANCELAR"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("APAGAR", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              ) ?? false;
            },
            onDismissed: (direction) {
               _deleteEntry(entry.id!, index); 
            },
            child: Card(
              elevation: 2.0, 
              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: InkWell(
                 borderRadius: BorderRadius.circular(12.0),
                 onTap: () => _navigateToAddEditScreen(entry),
                 child: Container(
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12.0),
                     gradient: LinearGradient(
                        colors: [moodColor.withOpacity(0.1), colorScheme.background],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                     )
                   ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                    leading: CircleAvatar(
                      backgroundColor: moodColor.withOpacity(0.8),
                      child: _getMoodIcon(entry.mood, Colors.white),
                    ),
                    title: Text(
                      entry.mood,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: moodColor),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                           DateFormat('EEEE, dd MMMM yyyy ' 'HH:mm', 'pt_BR').format(entry.date),
                           style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                         ),
                         if (entry.notes != null && entry.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              entry.notes!,
                              style: textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Icon _getMoodIcon(String mood, [Color? iconColor]) {
    final Color color = iconColor ?? _getMoodColor(mood);
    switch (mood) {
      case 'Feliz': return Icon(Icons.sentiment_very_satisfied, color: color);
      case 'Triste': return Icon(Icons.sentiment_very_dissatisfied, color: color);
      case 'Neutro': return Icon(Icons.sentiment_neutral, color: color);
      case 'Ansioso': return Icon(Icons.sentiment_dissatisfied, color: color);
      case 'Com Raiva': return Icon(Icons.sentiment_very_dissatisfied, color: color);
      case 'Animado': return Icon(Icons.sentiment_satisfied_alt, color: color);
      default: return Icon(Icons.sentiment_neutral, color: color);
    }
  }
} 