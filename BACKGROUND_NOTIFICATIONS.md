# Background Notifications Setup

This document explains how the background notification system works in the EcoBarangay app.

## How It Works

The app now supports notifications that appear even when the app is closed. Here's what happens:

### 1. Daily Schedule Notifications

- **When**: Every day at 6:00 AM (or when the app starts)
- **What**: Sends a consolidated notification with all waste collection schedules for the day
- **Who**: All residents in the affected barangay

### 2. Upcoming Collection Notifications

- **When**: 1 hour before each collection
- **What**: Reminds users about specific waste collection happening soon
- **Who**: Residents in the specific barangay

### 3. Scheduled Notifications

- **When**: Day before collection at 6:00 PM
- **What**: Advanced notice about tomorrow's collection
- **Who**: Residents in the affected barangay

## Key Features

### Background Processing

- Notifications are sent using OneSignal's REST API
- They work even when the app is completely closed
- No need for the app to be running in the background

### Smart Scheduling

- Notifications are scheduled in advance using OneSignal's `send_after` feature
- Prevents duplicate notifications
- Tracks which notifications have been sent

### Rich Data

- Each notification includes custom data for better handling
- Clicking notifications can navigate to specific screens
- Different notification types for different actions

## Testing the System

### 1. Test Immediate Background Notification

```dart
// Add this to any screen for testing
ElevatedButton(
  onPressed: () {
    ScheduleNotificationService.testBackgroundNotification();
  },
  child: Text('Test Background Notification'),
)
```

### 2. Test Scheduled Notification

```dart
// Add this to any screen for testing
ElevatedButton(
  onPressed: () {
    ScheduleNotificationService.testScheduledNotification();
  },
  child: Text('Test Scheduled Notification'),
)
```

### 3. Testing Steps

1. Add the test buttons to a screen
2. Tap the test button
3. Close the app completely
4. Wait for the notification to appear
5. Tap the notification to verify it opens the app

## Notification Types

The system supports different notification types:

- `daily_schedule`: Daily collection schedule
- `upcoming_collection`: Collection happening within the hour
- `scheduled_collection`: Advanced notice for tomorrow's collection
- `test_notification`: For testing purposes

## Troubleshooting

### Notifications Not Appearing

1. Check that notification permissions are granted
2. Verify OneSignal is properly initialized
3. Check the console logs for error messages
4. Ensure the device has internet connection

### Duplicate Notifications

1. Check the SharedPreferences tracking
2. Verify the notification scheduling logic
3. Look for multiple app instances

### Permission Issues

1. Go to device settings
2. Find the app in the notification settings
3. Ensure notifications are enabled
4. Check if the app is battery optimized (disable if needed)

## Configuration

### OneSignal Setup

- App ID: `836b9037-820a-4906-acf5-6d3e36d3899e`
- REST API Key: Configured in `onesignal_notif.dart`
- Tags: `barangay` for targeting specific areas

### Notification Timing

- Daily notifications: 6:00 AM
- Upcoming notifications: 1 hour before collection
- Scheduled notifications: 6:00 PM day before

## Future Enhancements

1. **Custom Notification Times**: Allow users to set preferred notification times
2. **Notification Preferences**: Let users choose which types of notifications to receive
3. **Smart Notifications**: Use machine learning to predict optimal notification times
4. **Rich Notifications**: Add images and action buttons to notifications
