# AI Analytics Integration Guide

## Setup Instructions

### 1. Get Your Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the API key

### 2. Configure the API Key

In `lib/screens/admin/features/ai_analytics.dart`, replace:

```dart
static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

with your actual API key:

```dart
static const String _geminiApiKey = 'your_actual_api_key_here';
```

### 3. Install Dependencies

Run this command to install the required packages:

```bash
flutter pub get
```

## How to Use

### 1. Navigate to AI Analytics

From your admin analytics screen, add a button to navigate to AI analytics:

```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIAnalyticsScreen(
          wasteTypeData: _wasteTypeData,
          monthlyCollectionData: _monthlyCollectionData,
          purokCollectionData: _purokCollectionData,
          recentCollections: _recentCollections,
          totalWasteCollected: _totalWasteCollected,
          totalCollections: _totalCollections,
          adminBarangay: _adminBarangay,
        ),
      ),
    );
  },
  icon: Icon(Icons.psychology),
  label: Text('AI Analytics'),
)
```

### 2. Features Available

#### Recommendations Tab

- **Waste Reduction**: AI suggests ways to reduce waste generation
- **Efficiency**: Recommendations for improving collection processes
- **Compliance**: Tips to reduce warnings and penalties
- **Sustainability**: Long-term environmental recommendations

#### Predictions Tab

- **Volume Predictions**: Forecasted waste collection for next 3 months
- **Trend Analysis**: Expected direction of waste generation trends
- **Challenges**: Potential issues to watch out for
- **Opportunities**: Areas for improvement and growth

#### Insights Tab

- **Patterns**: AI-identified patterns in waste generation
- **Hotspots**: Geographic areas with specific issues
- **Efficiency Insights**: Performance metrics and benchmarks
- **Anomalies**: Unusual patterns that need attention

## API Prompts

The AI uses three main prompts:

### 1. Recommendations Prompt

Analyzes waste data and provides actionable recommendations for:

- Waste reduction strategies
- Collection efficiency improvements
- Compliance enhancement
- Sustainability initiatives

### 2. Predictions Prompt

Uses historical data to predict:

- Future waste volumes
- Trend directions
- Potential challenges
- Growth opportunities

### 3. Insights Prompt

Identifies patterns and anomalies in:

- Waste composition
- Geographic distribution
- Temporal patterns
- Compliance issues

## Error Handling

The system handles various error scenarios:

- **API Key Missing**: Shows clear error message to configure API key
- **Network Issues**: Displays network error with retry option
- **API Limits**: Handles rate limiting gracefully
- **Invalid Data**: Provides fallback for malformed responses

## Customization

### Modify Prompts

You can customize the AI prompts in `ai_analytics.dart`:

- `_generateRecommendations()` - Change recommendation focus
- `_generatePredictions()` - Adjust prediction timeframe
- `_generateInsights()` - Modify insight categories

### Add New Categories

To add new recommendation categories:

1. Update the prompt in `_generateRecommendations()`
2. Add the category to `getFormattedRecommendations()`
3. Update the UI in `ai_analytics_screen.dart`

### Styling

The UI uses a consistent color scheme:

- Primary: `#2E7D32` (Green)
- Background: `#F5F7FA` (Light Gray)
- Cards: White with subtle shadows

## Security Notes

1. **Never commit your API key** to version control
2. Consider using environment variables for production
3. Monitor API usage to avoid exceeding limits
4. Implement rate limiting if needed

## Troubleshooting

### Common Issues

1. **"Please configure your Gemini API key"**

   - Solution: Add your API key to `ai_analytics.dart`

2. **"API request failed"**

   - Check your internet connection
   - Verify API key is correct
   - Check if you've exceeded API limits

3. **"Response could not be parsed as JSON"**

   - The AI response wasn't in expected format
   - Check the prompt structure
   - Verify data being sent to AI

4. **No data showing**
   - Ensure you're passing data from admin analytics
   - Check if the analysis completed successfully
   - Verify the data format matches expectations

### Debug Mode

To enable debug logging, add this to your main.dart:

```dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    // Enable debug prints for AI analytics
  }
  runApp(MyApp());
}
```

## Performance Tips

1. **Cache Results**: Consider caching AI analysis results to avoid repeated API calls
2. **Batch Requests**: Group related data for more efficient analysis
3. **Optimize Prompts**: Keep prompts concise but informative
4. **Error Recovery**: Implement retry logic for failed requests

## Future Enhancements

Potential improvements:

- Save analysis history
- Export AI reports to PDF
- Real-time analysis updates
- Custom AI models for specific waste types
- Integration with external waste management APIs
