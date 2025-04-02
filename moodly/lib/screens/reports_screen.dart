import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moodly/models/mood_entry.dart';
import 'package:moodly/services/api_service.dart';
import 'dart:convert';
import 'dart:math'; // For max calculation

enum ReportPeriod { week, month, allTime }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<MoodEntry> _allEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  ReportPeriod _selectedPeriod = ReportPeriod.week; // Default period

  // Define mood colors globally in the state for reuse
  final Map<String, Color> _moodColors = {
    'Feliz': Colors.green[400]!,
    'Triste': Colors.blue[400]!,
    'Neutro': Colors.grey[500]!,
    'Ansioso': Colors.orange[400]!,
    'Com Raiva': Colors.red[400]!,
    'Animado': Colors.purple[300]!,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all entries for chart data processing
      final response = await ApiService.getMoods().timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
         final responseData = json.decode(response.body);
         if (responseData['success'] == true) {
           final List<dynamic> data = responseData['data'];
           final entries = data.map((item) {
             try {
                // No longer need manual parsing here
                return MoodEntry.fromJson(item);
             } catch(e) { 
                 print("Error processing API item in ReportsScreen: $item, Error: $e");
                 return null; 
             }
           }).whereType<MoodEntry>().toList();

           setState(() {
             _allEntries = entries;
             _isLoading = false;
           });
         } else {
            throw Exception(responseData['message'] ?? 'API Error');
         }
      } else if (response.statusCode == 401) {
         // Handle unauthorized - TODO: Navigate to login?
         print("Unauthorized in ReportsScreen");
         setState(() {
            _errorMessage = "Sessão expirada. Faça login novamente.";
            _isLoading = false;
         });
      } else {
         throw Exception('Status code: ${response.statusCode}');
      }
    } catch (error) {
      print("Load Reports Data Error: $error");
       if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao buscar dados.';
          _isLoading = false;
        });
      }
    }
  }

  // Get filtered entries based on selected period
  List<MoodEntry> _getFilteredEntries() {
     final now = DateTime.now();
     DateTime startDate;

     switch (_selectedPeriod) {
       case ReportPeriod.week:
         startDate = now.subtract(const Duration(days: 7));
         break;
       case ReportPeriod.month:
         startDate = now.subtract(const Duration(days: 30));
         break;
       case ReportPeriod.allTime:
         return _allEntries; // Return all if 'allTime'
     }
     return _allEntries.where((entry) => entry.date.isAfter(startDate) && entry.date.isBefore(now)).toList();
  }

  // Process data for the selected period
  Map<String, double> _getMoodCounts(List<MoodEntry> entries) {
    final Map<String, double> counts = {};
    // Initialize counts for all known moods
     _moodColors.keys.forEach((mood) {
       counts[mood] = 0;
     });

    for (var entry in entries) {
       counts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String _getPeriodTitle() {
     switch (_selectedPeriod) {
       case ReportPeriod.week: return 'Últimos 7 Dias';
       case ReportPeriod.month: return 'Últimos 30 Dias';
       case ReportPeriod.allTime: return 'Todo o Período';
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatórios - ${_getPeriodTitle()}'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
                   Text(_errorMessage!, textAlign: TextAlign.center),
                   const SizedBox(height: 20),
                   ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      onPressed: _loadData,
                   )
                ],
             ),
          ),
       );
    }
    if (_allEntries.isEmpty) {
      return const Center(child: Text('Sem dados para gerar relatórios.'));
    }

    final filteredEntries = _getFilteredEntries();
    final moodCounts = _getMoodCounts(filteredEntries);
    final totalCount = moodCounts.values.fold(0.0, (sum, count) => sum + count);

     if (filteredEntries.isEmpty || totalCount == 0) {
       return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text('Nenhum humor registrado para "${_getPeriodTitle()}"', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                 const SizedBox(height: 20),
                 _buildPeriodSelector(), // Still show selector
              ],
            ),
          )
        );
    }

    // Data for charts
    final barChartGroups = _generateBarChartGroups(moodCounts);
    final pieChartSections = _generatePieChartSections(moodCounts, totalCount);
    final double maxBarCount = moodCounts.values.isNotEmpty ? moodCounts.values.reduce(max) : 1.0;

    return SingleChildScrollView( // Allow scrolling if charts get tall
       padding: const EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           _buildPeriodSelector(), // Add period selector UI
           const SizedBox(height: 24),

           // --- Bar Chart --- 
           Text(
             'Contagem de Humores (${_getPeriodTitle()})',
             style: Theme.of(context).textTheme.headlineSmall,
             textAlign: TextAlign.center,
           ),
           const SizedBox(height: 16),
           SizedBox(
             height: 250, // Give Bar chart a fixed height
             child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxBarCount * 1.2).ceilToDouble(),
                  barTouchData: BarTouchData(
                     enabled: true, // Keep touch interaction enabled
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Remove bottom text labels
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                         showTitles: true,
                         reservedSize: 28,
                         interval: (maxBarCount / 4).ceilToDouble().toDouble(), // Adjust interval
                         getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxBarCount / 4).ceilToDouble().toDouble()),
                  barGroups: barChartGroups,
                ),
                swapAnimationDuration: const Duration(milliseconds: 250),
             ),
           ),
           const SizedBox(height: 32),

           // --- Pie Chart --- 
            Text(
             'Distribuição Percentual (${_getPeriodTitle()})',
             style: Theme.of(context).textTheme.headlineSmall,
             textAlign: TextAlign.center,
           ),
           const SizedBox(height: 16),
           SizedBox(
             height: 250, // Fixed height for Pie chart area
             child: PieChart(
                PieChartData(
                   sections: pieChartSections,
                   centerSpaceRadius: 60, // Make it a donut chart
                   sectionsSpace: 2, // Space between sections
                   pieTouchData: PieTouchData( // Enable touch interactions
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                         // TODO: Handle touch (e.g., enlarge section)
                      },
                   ),
                ),
                swapAnimationDuration: const Duration(milliseconds: 250),
             ),
           ),
           const SizedBox(height: 16),
           _buildLegend(), // Add legend for pie chart
         ],
       ),
    );
  }

  // --- UI Helper Widgets ---

  Widget _buildPeriodSelector() {
    return SegmentedButton<ReportPeriod>(
       segments: const <ButtonSegment<ReportPeriod>>[
         ButtonSegment<ReportPeriod>(value: ReportPeriod.week, label: Text('7 Dias'), icon: Icon(Icons.calendar_view_week)),
         ButtonSegment<ReportPeriod>(value: ReportPeriod.month, label: Text('30 Dias'), icon: Icon(Icons.calendar_view_month)),
         ButtonSegment<ReportPeriod>(value: ReportPeriod.allTime, label: Text('Tudo'), icon: Icon(Icons.calendar_today)),
       ],
       selected: {_selectedPeriod},
       onSelectionChanged: (Set<ReportPeriod> newSelection) {
         setState(() {
           _selectedPeriod = newSelection.first;
           // Data processing happens automatically in build based on _selectedPeriod
         });
       },
       style: SegmentedButton.styleFrom(
         selectedBackgroundColor: Colors.deepPurple.shade100,
         // visualDensity: VisualDensity.compact, // Make buttons smaller
       ),
     );
  }

  Widget _buildLegend() {
     return Wrap(
       spacing: 16.0,
       runSpacing: 8.0,
       alignment: WrapAlignment.center,
       children: _moodColors.entries.map((entry) {
         return Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(width: 16, height: 16, color: entry.value),
             const SizedBox(width: 6),
             Text(entry.key),
           ],
         );
       }).toList(),
     );
  }

 // --- Chart Data Generators ---

  List<BarChartGroupData> _generateBarChartGroups(Map<String, double> counts) {
     final List<BarChartGroupData> groups = [];
     int index = 0;
     // Ensure consistent order based on _moodColors definition
     _moodColors.forEach((moodName, color) {
       final count = counts[moodName] ?? 0.0;
       if (count > 0) { // Only add bars for moods that actually occurred
          groups.add(
            BarChartGroupData(
              x: index++, // Use index for x position
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: color,
                  width: 18,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
              ],
            ),
          );
        } 
      });
      // Need to re-map 'x' if filtering occurred? No, BarChart handles gaps if needed.
      // Let's re-index just in case and filter zero counts
      final filteredCounts = Map.fromEntries(counts.entries.where((e) => e.value > 0));
      return filteredCounts.entries.toList().asMap().entries.map((entry) {
         final idx = entry.key;
         final moodName = entry.value.key;
         final countVal = entry.value.value;
         final colorVal = _getMoodColor(moodName);
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: countVal,
                color: colorVal,
                width: 18,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
            ],
          );
      }).toList();
  }

  List<PieChartSectionData> _generatePieChartSections(Map<String, double> counts, double totalCount) {
    if (totalCount == 0) return [];
    return counts.entries.map((entry) {
      final moodName = entry.key;
      final count = entry.value;
      final percentage = (count / totalCount) * 100;
      final color = _getMoodColor(moodName);

      // Don't show sections for moods with 0 count
      if (count == 0) return null;

      return PieChartSectionData(
         value: count, // Value drives the size
         title: '${percentage.toStringAsFixed(0)}%', // Display percentage
         color: color,
         radius: 80, // Adjust radius as needed
         titleStyle: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            color: Colors.white, // White text on colored section
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)], // Text shadow
         ),
      );
    }).whereType<PieChartSectionData>().toList(); // Filter out nulls
  }

  Color _getMoodColor(String mood) {
     return _moodColors[mood] ?? Colors.grey[500]!;
  }
} 