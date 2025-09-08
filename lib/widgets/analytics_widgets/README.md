# Analytics Widgets

This directory contains reusable widget components for the admin analytics dashboard. These widgets have been extracted from the main `admin_analytics.dart` file to improve code organization and maintainability.

## Widgets

### 1. `AnalyticsHeader`

- **Purpose**: Displays the main header with title, barangay info, and refresh button
- **Props**: `adminBarangay`, `primaryColor`, `onRefresh`
- **Usage**: Top of the analytics screen

### 2. `TimeFilter`

- **Purpose**: Provides time period selection dropdown with month picker
- **Props**: `selectedTimeFilter`, `selectedMonth`, `timeFilters`, `primaryColor`, `textPrimaryColor`, `onTimeFilterChanged`, `onMonthSelected`
- **Usage**: Below the header for filtering data by time period

### 3. `OverviewCards`

- **Purpose**: Displays summary statistics in a grid layout
- **Props**: `totalWasteCollected`, `totalCollections`, `totalWarnings`, `totalPenalties`, `primaryColor`, `secondaryColor`, `textSecondaryColor`
- **Usage**: Shows key metrics at the top of the dashboard

### 4. `WasteTypeChart`

- **Purpose**: Bar chart showing waste type distribution
- **Props**: `wasteTypeData`, `totalWasteCollected`, `isLoading`, `onRefresh`, `primaryColor`, `textSecondaryColor`
- **Usage**: Left side of the first chart row

### 5. `PurokDistributionChart`

- **Purpose**: Pie chart showing collection distribution by purok
- **Props**: `purokCollectionData`, `totalWasteCollected`, `primaryColor`, `textSecondaryColor`
- **Usage**: Right side of the first chart row

### 6. `MonthlyCollectionChart`

- **Purpose**: Line chart showing monthly collection trends or daily data for selected month
- **Props**: `monthlyCollectionData`, `dailyScansCount`, `selectedTimeFilter`, `selectedMonth`, `isLoading`, `onRefresh`, `primaryColor`, `textSecondaryColor`
- **Usage**: Left side of the second chart row

### 7. `ResidentScansChart`

- **Purpose**: Line chart showing daily resident scan counts
- **Props**: `dailyScansCount`, `selectedTimeFilter`, `selectedMonth`, `isLoading`, `accentColor`, `textSecondaryColor`
- **Usage**: Right side of the second chart row

### 8. `RecentCollections`

- **Purpose**: List view showing recent waste collections with warnings/penalties
- **Props**: `recentCollections`, `selectedTimeFilter`, `selectedMonth`, `primaryColor`, `textSecondaryColor`
- **Usage**: Bottom of the dashboard

## Benefits of This Structure

1. **Modularity**: Each chart is now a separate, reusable component
2. **Maintainability**: Easier to modify individual charts without affecting others
3. **Testability**: Each widget can be tested independently
4. **Reusability**: Widgets can be used in other parts of the app
5. **Cleaner Code**: Main analytics file is now much shorter and focused on data management
6. **Separation of Concerns**: UI logic is separated from business logic

## Usage Example

```dart
import 'features/analytics_widgets/index.dart';

// In your main analytics screen
WasteTypeChart(
  wasteTypeData: _wasteTypeData,
  totalWasteCollected: _totalWasteCollected,
  isLoading: _isLoading,
  onRefresh: _loadAnalyticsData,
  primaryColor: primaryColor,
  textSecondaryColor: textSecondaryColor,
)
```

## File Size Reduction

The main `admin_analytics.dart` file has been reduced from **3,351 lines** to approximately **1,800 lines** - a reduction of about **46%**.

## Maintenance

When updating charts:

1. Modify the specific widget file
2. Update the props interface if needed
3. Test the individual widget
4. The main analytics screen will automatically use the updated widget

This structure makes the codebase much more maintainable and follows Flutter best practices for widget composition.
