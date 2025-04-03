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

  // Descrições para cada humor
  final Map<String, String> _moodDescriptions = {
    'Feliz': 'Estado de bem-estar e contentamento',
    'Triste': 'Sentimento de melancolia ou pesar',
    'Neutro': 'Estado emocional equilibrado',
    'Ansioso': 'Sensação de preocupação ou nervosismo',
    'Com Raiva': 'Sentimento intenso de descontentamento',
    'Animado': 'Estado de entusiasmo e energia positiva',
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
    
    // Calcular o humor predominante
    String predominantMood = '';
    double maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        predominantMood = mood;
      }
    });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.grey.shade100],
        ),
      ),
      child: SingleChildScrollView(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             _buildPeriodSelector(),
             const SizedBox(height: 16),
             
             // Resumo estatístico
             Card(
               elevation: 4,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'Resumo Estatístico',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.deepPurple,
                       ),
                     ),
                     const Divider(height: 24),
                     Row(
                       children: [
                         Expanded(
                           child: _buildStatCard(
                             icon: Icons.sentiment_very_satisfied,
                             title: 'Humor #1',
                             value: predominantMood,
                             color: _getMoodColor(predominantMood),
                           ),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: _buildStatCard(
                             icon: Icons.bar_chart,
                             title: 'Registros',
                             value: totalCount.toInt().toString(),
                             color: Colors.deepPurple,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 8),
                     Text(
                       'Você tem registrado predominantemente o humor "${predominantMood}" (${_moodDescriptions[predominantMood]})',
                       style: Theme.of(context).textTheme.bodyMedium,
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 24),

             // --- Bar Chart --- 
             Card(
               elevation: 4,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   children: [
                     Text(
                       'Contagem de Humores',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.deepPurple,
                       ),
                     ),
                     Text(
                       _getPeriodTitle(),
                       style: Theme.of(context).textTheme.titleSmall?.copyWith(
                         color: Colors.grey[600],
                       ),
                     ),
                     const SizedBox(height: 16),
                     SizedBox(
                       height: 250,
                       child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (maxBarCount * 1.2).ceilToDouble(),
                            barTouchData: BarTouchData(
                              enabled: true,
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    List<String> moodLabels = _moodColors.keys.toList();
                                    if (value >= 0 && value < moodLabels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          moodLabels[value.toInt()],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 28,
                                   interval: (maxBarCount / 4).ceilToDouble().toDouble(),
                                   getTitlesWidget: (value, meta) => Text(
                                     value.toInt().toString(),
                                     style: const TextStyle(
                                       color: Colors.grey,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 10,
                                     )
                                   ),
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                left: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: (maxBarCount / 4).ceilToDouble().toDouble(),
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            barGroups: barChartGroups,
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 400),
                          swapAnimationCurve: Curves.easeInOutCubic,
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 24),

             // --- Pie Chart --- 
             Card(
               elevation: 4,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   children: [
                     Text(
                       'Distribuição Percentual',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.deepPurple,
                       ),
                     ),
                     Text(
                       _getPeriodTitle(),
                       style: Theme.of(context).textTheme.titleSmall?.copyWith(
                         color: Colors.grey[600],
                       ),
                     ),
                     const SizedBox(height: 16),
                     AspectRatio(
                       aspectRatio: 1.3,
                       child: PieChart(
                          PieChartData(
                             sections: pieChartSections,
                             centerSpaceRadius: 50,
                             sectionsSpace: 3,
                             pieTouchData: PieTouchData(
                                enabled: true,
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                   // Responder ao toque (futuro)
                                },
                             ),
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 400),
                          swapAnimationCurve: Curves.easeInOutCubic,
                       ),
                     ),
                     const SizedBox(height: 16),
                     _buildDetailedLegend(),
                   ],
                 ),
               ),
             ),
             
             // Tabela de dados para assistente de IA
             const SizedBox(height: 24),
             Card(
               elevation: 4,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Icon(
                           Icons.insights,
                           color: Colors.deepPurple,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           'Dados Detalhados para Análise',
                           style: Theme.of(context).textTheme.titleLarge?.copyWith(
                             fontWeight: FontWeight.bold,
                             color: Colors.deepPurple,
                           ),
                         ),
                       ],
                     ),
                     const Divider(height: 24),
                     _buildDataTable(moodCounts, totalCount),
                   ],
                 ),
               ),
             ),
           ],
         ),
      ),
    );
  }
  
  // Componente para estatísticas
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
  
  // Uma legenda mais detalhada
  Widget _buildDetailedLegend() {
    return Column(
      children: _moodColors.entries.map((entry) {
        final mood = entry.key;
        final color = entry.value;
        final count = _getFilteredEntries().where((e) => e.mood == mood).length;
        final percentage = _getFilteredEntries().isEmpty 
            ? 0.0 
            : (count / _getFilteredEntries().length) * 100;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 16, 
                height: 16, 
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mood,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${count.toString()} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  // Tabela detalhada para análise de IA
  Widget _buildDataTable(Map<String, double> moodCounts, double totalCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey.shade100),
        border: TableBorder.all(
          color: Colors.grey.shade300,
          width: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        columns: [
          DataColumn(
            label: Text('Humor', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Contagem', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Percentual', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        rows: moodCounts.entries.map((entry) {
          final mood = entry.key;
          final count = entry.value;
          final percentage = (count / totalCount) * 100;
          
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12, 
                      height: 12, 
                      decoration: BoxDecoration(
                        color: _getMoodColor(mood),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(mood),
                  ],
                ),
              ),
              DataCell(Text(count.toInt().toString())),
              DataCell(Text('${percentage.toStringAsFixed(1)}%')),
              DataCell(Text(_moodDescriptions[mood] ?? '')),
            ],
          );
        }).toList(),
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
    
    // Usar lista fixa de humores para manter ordem consistente
    final moodList = _moodColors.keys.toList();
    
    for (int i = 0; i < moodList.length; i++) {
      final mood = moodList[i];
      final count = counts[mood] ?? 0.0;
      
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count,
              color: _getMoodColor(mood),
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6), 
                topRight: Radius.circular(6)
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: counts.values.isEmpty ? 1 : counts.values.reduce(max) * 1.1,
                color: Colors.grey.shade200,
              ),
            ),
          ],
          showingTooltipIndicators: count > 0 ? [0] : [],
        ),
      );
    }
    
    return groups;
  }

  List<PieChartSectionData> _generatePieChartSections(Map<String, double> counts, double totalCount) {
    if (totalCount == 0) return [];
    
    // Usar lista fixa de humores para manter ordem consistente
    final List<PieChartSectionData> sections = [];
    final moodList = _moodColors.keys.toList();
    
    for (int i = 0; i < moodList.length; i++) {
      final mood = moodList[i];
      final count = counts[mood] ?? 0.0;
      final percentage = (count / totalCount) * 100;
      
      // Não mostrar seções para humores com contagem 0
      if (count == 0) continue;
      
      sections.add(
        PieChartSectionData(
          value: count,
          title: '${percentage.toStringAsFixed(0)}%',
          color: _getMoodColor(mood),
          radius: 85,
          titleStyle: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
          badgeWidget: _buildPieBadge(mood),
          badgePositionPercentageOffset: 0.98,
        ),
      );
    }
    
    return sections;
  }
  
  Widget? _buildPieBadge(String mood) {
    IconData iconData;
    
    switch (mood) {
      case 'Feliz':
        iconData = Icons.sentiment_very_satisfied;
        break;
      case 'Triste':
        iconData = Icons.sentiment_very_dissatisfied;
        break;
      case 'Neutro':
        iconData = Icons.sentiment_neutral;
        break;
      case 'Ansioso':
        iconData = Icons.psychology;
        break;
      case 'Com Raiva':
        iconData = Icons.mood_bad;
        break;
      case 'Animado':
        iconData = Icons.celebration;
        break;
      default:
        return null;
    }
    
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Icon(iconData, size: 16, color: _getMoodColor(mood)),
    );
  }

  Color _getMoodColor(String mood) {
     return _moodColors[mood] ?? Colors.grey[500]!;
  }
} 