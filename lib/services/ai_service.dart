import 'package:moodly/models/mood_entry.dart';

class AIService {
  // Gera insights baseados nos dados de humor
  static Map<String, dynamic> generateInsights(List<MoodEntry> entries, {String period = 'semana'}) {
    // Se não houver entradas suficientes, retorne uma mensagem padrão
    if (entries.isEmpty || entries.length < 3) {
      return {
        'summary': 'Dados insuficientes para análise',
        'message': 'Continue registrando seus humores diariamente para receber insights personalizados.',
        'tips': [
          'Tente registrar seu humor pelo menos uma vez por dia.',
          'Adicione notas aos seus registros para um contexto mais rico.',
          'Acompanhe seus padrões ao longo do tempo para insights mais precisos.'
        ],
        'dominant_mood': null,
        'mood_changes': [],
        'hasEnoughData': false
      };
    }

    // Calcular o humor predominante
    Map<String, int> moodCounts = {};
    for (var entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    
    // Encontrar o humor mais frequente
    String dominantMood = '';
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantMood = mood;
      }
    });
    
    // Calcular a porcentagem do humor predominante
    double dominantPercentage = (maxCount / entries.length) * 100;
    
    // Ordenar as entradas por data
    final sortedEntries = List<MoodEntry>.from(entries);
    sortedEntries.sort((a, b) => a.date.compareTo(b.date));
    
    // Detectar padrões de alteração de humor
    List<Map<String, dynamic>> moodChanges = [];
    String? prevMood;
    for (var entry in sortedEntries) {
      if (prevMood != null && prevMood != entry.mood) {
        moodChanges.add({
          'from': prevMood,
          'to': entry.mood,
          'date': entry.date,
        });
      }
      prevMood = entry.mood;
    }
    
    // Gerar resumo com base na análise
    String summary = 'Análise de humor desta $period';
    
    // Mensagem principal
    String message = '';
    if (dominantPercentage > 70) {
      message = 'Seu humor esteve predominantemente $dominantMood nesta $period (${dominantPercentage.toStringAsFixed(0)}% do tempo).';
    } else if (moodChanges.length > entries.length * 0.4) {
      message = 'Você experimentou várias alterações de humor nesta $period. Suas emoções estiveram bastante variáveis.';
    } else {
      message = 'Seu humor teve uma distribuição equilibrada nesta $period, com $dominantMood sendo o mais frequente.';
    }
    
    // Gerar dicas personalizadas
    List<String> tips = _generateTips(dominantMood, moodChanges.length, entries);
    
    return {
      'summary': summary,
      'message': message,
      'tips': tips,
      'dominant_mood': dominantMood,
      'mood_changes': moodChanges,
      'hasEnoughData': true
    };
  }
  
  // Gera dicas personalizadas com base no humor predominante
  static List<String> _generateTips(String dominantMood, int changeCount, List<MoodEntry> entries) {
    List<String> tips = [];
    
    // Dicas baseadas no humor predominante
    switch (dominantMood) {
      case 'Feliz':
      case 'Animado':
        tips.add('Continue com as atividades que estão contribuindo para seu bom humor.');
        tips.add('Compartilhe sua energia positiva com pessoas próximas a você.');
        break;
      case 'Triste':
        tips.add('Tente incluir atividades que você gosta em sua rotina diária.');
        tips.add('Considere conversar com alguém de confiança sobre seus sentimentos.');
        tips.add('Pequenas doses de exercício físico podem ajudar a melhorar o humor.');
        break;
      case 'Ansioso':
        tips.add('Experimente técnicas de respiração profunda quando se sentir ansioso.');
        tips.add('Tente reduzir o consumo de cafeína, que pode aumentar a ansiedade.');
        tips.add('Estabeleça uma rotina de sono regular para ajudar a reduzir a ansiedade.');
        break;
      case 'Com Raiva':
        tips.add('Quando sentir raiva, tente fazer uma pausa antes de reagir.');
        tips.add('Praticar atividade física pode ser uma boa maneira de liberar a tensão.');
        tips.add('Considere técnicas de gerenciamento de estresse como meditação ou yoga.');
        break;
      case 'Neutro':
        tips.add('Experimente novas atividades para estimular emoções positivas.');
        tips.add('Manter um diário de gratidão pode ajudar a melhorar seu bem-estar emocional.');
        break;
    }
    
    // Dicas baseadas nas mudanças de humor
    if (changeCount > entries.length * 0.4) {
      tips.add('Suas frequentes mudanças de humor podem estar relacionadas a fatores externos. Tente identificar possíveis gatilhos.');
      tips.add('Estabeleça uma rotina diária para ajudar a estabilizar seu humor.');
    } else if (changeCount < entries.length * 0.2) {
      tips.add('Seu humor está relativamente estável, o que é positivo para o bem-estar emocional.');
    }
    
    // Dica geral sempre presente
    tips.add('Continue registrando seus humores regularmente para obter insights mais precisos.');
    
    return tips;
  }
  
  // Simulação de chamada a uma API de IA externa (para uso futuro)
  static Future<Map<String, dynamic>> getAIPoweredInsights(List<MoodEntry> entries) async {
    // Esta função pode ser expandida para integrar com APIs como OpenAI ou Google AI
    // Por enquanto, usamos nossa própria lógica
    
    // Simular tempo de processamento da IA
    await Future.delayed(const Duration(milliseconds: 800));
    
    return generateInsights(entries);
  }
} 