import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\screens\admin_dashboard_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import if missing
if "package:fl_chart/fl_chart.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:fl_chart/fl_chart.dart';")

# 2. Add the _buildScansChart() method before the final } of _AdminDashboardScreenState
# Wait, let's just insert it at the end of the file before the last `}`.
chart_method = """

  Widget _buildScansChart() {
    // Generate mock data for the last 7 days for the chart
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText('Scan Diagnostics (Last 7 Days)', 
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 50,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(days[value.toInt() % 7], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.outlineVariant.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 15, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 25, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 10, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 30, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 20, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 45, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 35, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}"""
content = re.sub(r'}\s*$', chart_method, content)


# 3. Inject it at line 806 (after the Wrap ends)
target = """            },
          ),

          const SizedBox(height: 24),

          // Live Activity Stream"""

replacement = """            },
          ),

          const SizedBox(height: 24),
          _buildScansChart(),
          const SizedBox(height: 24),

          // Live Activity Stream"""

content = content.replace(target, replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Injected fl_chart into admin dashboard")
