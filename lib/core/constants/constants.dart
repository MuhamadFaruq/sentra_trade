class StrategyRule {
  final String name;
  final double minRR;
  final String description;

  StrategyRule({required this.name, required this.minRR, required this.description});
}

class AppConstants {
  static final List<StrategyRule> strategyRules = [
    StrategyRule(
      name: 'Breakout Trendline', 
      minRR: 2.0, 
      description: 'Target high/low terdekat'
    ),
    StrategyRule(
      name: 'Supply Demand', 
      minRR: 3.0, 
      description: 'Target pada zona supply/demand berikutnya'
    ),
    StrategyRule(
      name: 'Trend Continue', 
      minRR: 1.5, 
      description: 'Follow the trend'
    ),
    StrategyRule(
      name: 'Orderflow', 
      minRR: 2.0, 
      description: 'Ikuti jejak institusi'
    ),
  ];
  static List<String> get entryStrategies => 
    strategyRules.map((e) => e.name).toList();
}