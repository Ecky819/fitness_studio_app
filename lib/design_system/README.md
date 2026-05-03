# Premium Fitness App Design System

A comprehensive, production-ready design system for premium fitness applications with dark mode first approach.

## 🎨 Design Philosophy

- **Dark Mode First**: Optimized for gym environments with low lighting
- **Minimal & Modern**: Clean aesthetics with purposeful design
- **High Contrast**: Excellent accessibility and readability
- **Consistent**: Unified design language across all components

## 📦 What's Included

### Colors (`app_colors.dart`)

- Primary, success, error, warning color palettes
- Background, surface, and text color hierarchies
- Gradient definitions for premium effects
- Semantic color utilities

### Typography (`app_text_styles.dart`)

- Complete text style hierarchy (H1-H4, body, labels, captions)
- Consistent font weights, sizes, and spacing
- Semantic styles (success, error, warning, etc.)
- Utility methods for color and weight modifications

### Spacing (`app_spacing.dart`)

- Consistent spacing scale (xs, sm, md, lg, xl, xxl, xxxl)
- Component-specific spacing values
- Border radius, icon sizes, and elevation scales
- Grid and layout utilities

### Animations (`app_animations.dart`)

- Standard duration constants (fast, normal, slow, etc.)
- Common animation curves (ease, bounce, sharp)
- Pre-built transition widgets
- Utility methods for custom animations

### Components

- **Buttons**: Primary, secondary, ghost variants with loading states
- **Status Cards**: Success, error, warning, info variants
- **Glass Containers**: Premium frosted glass effects
- **UI Blocks**: Section headers, content cards, list items, empty/error states

### Theme (`app_theme.dart`)

- Complete Flutter ThemeData integration
- Dark/light theme variants
- Material 3 compatibility
- System UI styling

## 🚀 Quick Start

```dart
import 'package:fitness_studio_app/design_system/design_system.dart';

// Use the theme
MaterialApp(
  theme: AppTheme.dark, // or AppTheme.light
  home: MyHomePage(),
)

// Use colors
Container(
  color: AppColors.primary,
  child: Text(
    'Hello',
    style: AppTextStyles.h1,
  ),
)

// Use components
AppPrimaryButton(
  text: 'Get Started',
  onPressed: () => print('Pressed!'),
)

// Use spacing
Padding(
  padding: EdgeInsets.all(AppSpacing.md),
  child: Text('Content'),
)
```

## 🎯 Component Usage Examples

### Buttons

```dart
// Primary button with loading
AppPrimaryButton(
  text: 'Save Workout',
  isLoading: true,
  onPressed: _saveWorkout,
)

// Secondary button
AppSecondaryButton(
  text: 'Cancel',
  onPressed: _cancel,
)

// Ghost button
AppGhostButton(
  text: 'Learn More',
  onPressed: _learnMore,
)
```

### Status Cards

```dart
// Success status
AppStatusCard(
  title: 'Workout Completed!',
  subtitle: 'Great job on your session',
  type: StatusType.success,
)

// Error status
AppStatusCard(
  title: 'Connection Failed',
  subtitle: 'Please check your internet',
  type: StatusType.error,
  onTap: _retryConnection,
)
```

### Glass Containers

```dart
// Light glass effect
AppLightGlassContainer(
  child: Text('Premium Content'),
)

// Colored glass
AppColoredGlassContainer(
  tintColor: AppColors.primary,
  child: Icon(Icons.star),
)
```

### UI Blocks

```dart
// Section header
AppSectionHeader(
  title: 'My Workouts',
  subtitle: 'Track your progress',
  trailing: Icon(Icons.add),
)

// Content card
AppContentCard(
  child: Column(
    children: [
      Text('Card Content'),
    ],
  ),
)

// List item
AppListItem(
  leading: Icon(Icons.fitness_center),
  title: 'Bench Press',
  subtitle: 'Chest workout',
  trailing: Text('3 sets'),
  onTap: _openWorkout,
)
```

## 🎨 Color Palette

### Primary Colors

- **Primary**: `#00D4FF` (Electric Blue)
- **Primary Variant**: `#0099CC` (Deeper Blue)
- **Primary Light**: `#66E0FF` (Light Blue)

### Semantic Colors

- **Success**: `#00FF88` (Vibrant Green)
- **Error**: `#FF4444` (Bright Red)
- **Warning**: `#FFAA00` (Orange)
- **Info**: `#44AAFF` (Light Blue)

### Background Colors

- **Background**: `#0F0F23` (Deep Navy)
- **Surface**: `#1E1E3F` (Elevated Surface)
- **Surface Variant**: `#2A2A4A` (Alternative Surface)

## 📝 Typography Scale

| Style | Size | Weight | Use Case |
|-------|------|--------|----------|
| H1 | 32px | 700 | Main headings |
| H2 | 24px | 600 | Section headings |
| H3 | 20px | 600 | Subsection headings |
| H4 | 18px | 600 | Card titles |
| Body Large | 16px | 400 | Primary body text |
| Body | 14px | 400 | Standard body text |
| Label Large | 14px | 500 | Button text |
| Caption | 12px | 400 | Helper text |

## 📏 Spacing Scale

| Token | Value | Use Case |
|-------|-------|----------|
| xs | 4px | Tight spacing |
| sm | 8px | Component padding |
| md | 16px | Standard spacing |
| lg | 24px | Section spacing |
| xl | 32px | Large gaps |
| xxl | 48px | Major sections |

## 🎬 Animation Guidelines

### Durations

- **Extra Fast**: 100ms (micro-interactions)
- **Fast**: 200ms (button presses)
- **Normal**: 300ms (standard transitions)
- **Slow**: 500ms (page transitions)
- **Extra Slow**: 700ms (entrance animations)

### Curves

- **Standard**: `easeInOut` (most transitions)
- **Accelerate**: `easeIn` (exits, removals)
- **Bounce**: `elasticOut` (success states)
- **Sharp**: `easeInExpo` (attention-grabbing)

## 🔧 Customization

### Custom Colors

```dart
class MyColors extends AppColors {
  static const Color brandPink = Color(0xFFFF6B9D);
  static const Color brandPurple = Color(0xFF8B5CF6);
}
```

### Custom Components

```dart
class MyCustomButton extends AppPrimaryButton {
  const MyCustomButton({
    super.key,
    required super.text,
    super.onPressed,
  });

  // Custom styling overrides
}
```

### Theme Extensions

```dart
final customTheme = AppTheme.custom(
  brightness: Brightness.dark,
  primaryColor: MyColors.brandPink,
  fontFamily: 'CustomFont',
);
```

## 📱 Responsive Design

The design system includes responsive utilities:

```dart
// Responsive spacing
double responsiveSpacing(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return AppSpacing.sm;
  if (width < 1200) return AppSpacing.md;
  return AppSpacing.lg;
}

// Responsive text
TextStyle responsiveText(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return AppTextStyles.body;
  return AppTextStyles.bodyLarge;
}
```

## ♿ Accessibility

- **High Contrast**: All text meets WCAG AA standards
- **Color Blind Friendly**: Semantic colors work with color vision deficiencies
- **Touch Targets**: Minimum 44px touch targets
- **Focus Indicators**: Clear focus states for keyboard navigation

## 🔄 Maintenance

### Adding New Colors

1. Add to `AppColors` class
2. Update semantic variants if needed
3. Test contrast ratios
4. Update documentation

### Adding New Components

1. Create component file in `components/`
2. Use existing design tokens
3. Add to `design_system.dart` exports
4. Update documentation and examples

### Updating Theme

1. Modify `AppTheme._buildTheme()`
2. Test on multiple platforms
3. Update component themes if needed

## 📋 Checklist for New Features

- [ ] Uses design system colors
- [ ] Follows typography hierarchy
- [ ] Implements proper spacing
- [ ] Includes loading/error states
- [ ] Works in both light/dark themes
- [ ] Responsive design
- [ ] Accessibility compliant
- [ ] Documented usage examples

---

**Built for premium fitness experiences** 🏋️‍♀️✨
